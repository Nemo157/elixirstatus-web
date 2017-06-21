defmodule ElixirStatus.GitHubAuthController do
  use ElixirStatus.Web, :controller

  alias ElixirStatus.Persistence.User

  @allowed_users Application.get_env(:elixir_status, :allowed_users)

  @doc """
  This action is reached via `/auth` and redirects to the OAuth2 provider
  based on the chosen strategy.
  """
  def sign_in(conn, _params) do
    handle_sign_in_for(Mix.env, conn)
  end

  defp handle_sign_in_for(:test, conn) do
    sign_in_via_auth conn, %{"name" => "René Föhring", "login" => "rrrene", "email" => "rf@bamaru.de", "avatar_url" => "http://elixirstatus.com/images/avatar_rrrene.jpg"}
  end

  defp handle_sign_in_for(_, conn) do
    redirect conn, external: GitHubAuth.authorize_url!
  end

  @doc """
  This action is reached via `/auth/sign_out` and redirects to the OAuth2 provider
  based on the chosen strategy.
  """
  def sign_out(conn, _params) do
    conn
    |> clear_session
    |> redirect(to: "/?just_signed_out=true")
  end

  @doc """
  This action is reached via `/auth/callback` is the the callback URL that
  the OAuth2 provider will redirect the user back to with a `code` that will
  be used to request an access token. The access token will then be used to
  access protected resources on behalf of the user.
  """
  def callback(conn, %{"code" => code}) do
    # Exchange an auth code for an access token
    client = GitHubAuth.get_token!(code: code)
    response = OAuth2.Client.get!(client, "/user")
    user_auth_params = response.body

    sign_in_via_auth(conn, user_auth_params)
  end

  defp sign_in_allowed?(user_auth_params) do
    case @allowed_users do
      nil -> true
      _ -> Enum.member?(@restricted_users, user_auth_params["login"])
    end
  end

  defp sign_in_via_auth(conn, user_auth_params) do
    current_user = User.find_or_create(user_auth_params)

    if sign_in_allowed?(user_auth_params) do
      conn
      |> put_session(:current_user_id, current_user.id)
      |> assign(:current_user, current_user)
      |> redirect(to: "/?just_signed_in=true")
    else
      conn |> redirect(to: "/")
    end
  end
end
