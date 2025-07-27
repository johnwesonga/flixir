defmodule FlixirWeb.AuthController do
  @moduledoc """
  Controller for handling authentication session management.

  This controller handles the session storage and clearing operations
  that need to be done outside of LiveView context.
  """

  use FlixirWeb, :controller

  alias FlixirWeb.Plugs.AuthSession

  def store_session(conn, %{"session_id" => session_id} = params) do
    redirect_to = Map.get(params, "redirect_to", "/")

    conn
    |> AuthSession.put_session_id(session_id)
    |> AuthSession.clear_redirect_after_login()
    |> redirect(to: redirect_to)
  end

  def clear_session(conn, _params) do
    conn
    |> AuthSession.clear_session_id()
    |> redirect(to: "/")
  end
end
