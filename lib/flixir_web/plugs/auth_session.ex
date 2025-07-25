defmodule FlixirWeb.Plugs.AuthSession do
  @moduledoc """
  Plug for session management and authentication validation.

  This plug handles:
  - Session validation from cookies
  - User context injection to conn assigns
  - Automatic session expiration and cleanup
  - Redirect logic for unauthenticated users when required

  ## Usage

  Add to your pipeline in router.ex:

      pipeline :authenticated do
        plug :browser
        plug FlixirWeb.Plugs.AuthSession, require_auth: true
      end

  Or use without requiring authentication:

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug FlixirWeb.Plugs.AuthSession
        # ... other plugs
      end

  ## Options

  - `:require_auth` - Boolean, defaults to false. When true, redirects
    unauthenticated users to login page.
  - `:redirect_to` - String, defaults to "/auth/login". Where to redirect
    unauthenticated users when require_auth is true.

  ## Assigns

  This plug sets the following assigns on the conn:

  - `:current_user` - Map of current user data from TMDB, or nil
  - `:current_session` - Session struct, or nil
  - `:authenticated?` - Boolean indicating if user is authenticated

  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Flixir.Auth

  require Logger

  @session_key "tmdb_session_id"

  def init(opts) do
    %{
      require_auth: Keyword.get(opts, :require_auth, false),
      redirect_to: Keyword.get(opts, :redirect_to, "/auth/login")
    }
  end

  def call(conn, opts) do
    session_id = get_session(conn, @session_key)

    conn
    |> validate_and_assign_session(session_id)
    |> maybe_require_authentication(opts)
  end

  # Private functions

  defp validate_and_assign_session(conn, nil) do
    # No session ID in cookie
    assign_unauthenticated(conn)
  end

  defp validate_and_assign_session(conn, session_id) when is_binary(session_id) do
    case Auth.validate_session(session_id) do
      {:ok, session} ->
        # Session is valid, get current user data
        case Auth.get_current_user(session_id) do
          {:ok, user_data} ->
            Logger.debug("Successfully validated session for user: #{user_data["username"]}")

            conn
            |> assign(:current_user, user_data)
            |> assign(:current_session, session)
            |> assign(:authenticated?, true)

          {:error, reason} ->
            Logger.warning(
              "Failed to get user data for session #{session_id}: #{inspect(reason)}"
            )

            clear_session_and_assign_unauthenticated(conn)
        end

      {:error, :session_expired} ->
        Logger.info("Session #{session_id} has expired, clearing from cookie")
        clear_session_and_assign_unauthenticated(conn)

      {:error, :not_found} ->
        Logger.info("Session #{session_id} not found in database, clearing from cookie")
        clear_session_and_assign_unauthenticated(conn)

      {:error, reason} ->
        Logger.warning("Session validation failed for #{session_id}: #{inspect(reason)}")
        clear_session_and_assign_unauthenticated(conn)
    end
  end

  defp validate_and_assign_session(conn, _invalid_session_id) do
    # Invalid session ID format
    clear_session_and_assign_unauthenticated(conn)
  end

  defp assign_unauthenticated(conn) do
    conn
    |> assign(:current_user, nil)
    |> assign(:current_session, nil)
    |> assign(:authenticated?, false)
  end

  defp clear_session_and_assign_unauthenticated(conn) do
    conn
    |> delete_session(@session_key)
    |> assign_unauthenticated()
  end

  defp maybe_require_authentication(conn, %{require_auth: false}) do
    # Authentication not required, continue
    conn
  end

  defp maybe_require_authentication(conn, %{require_auth: true, redirect_to: redirect_path}) do
    if conn.assigns.authenticated? do
      # User is authenticated, continue
      conn
    else
      # User is not authenticated, redirect to login
      Logger.info("Redirecting unauthenticated user to #{redirect_path}")

      conn
      |> put_session(:redirect_after_login, conn.request_path)
      |> redirect(to: redirect_path)
      |> halt()
    end
  end

  @doc """
  Helper function to store session ID in cookie after successful authentication.

  ## Examples

      iex> put_session_id(conn, "session_123")
      %Plug.Conn{}

  """
  def put_session_id(conn, session_id) when is_binary(session_id) do
    put_session(conn, @session_key, session_id)
  end

  @doc """
  Helper function to clear session from cookie during logout.

  ## Examples

      iex> clear_session_id(conn)
      %Plug.Conn{}

  """
  def clear_session_id(conn) do
    delete_session(conn, @session_key)
  end

  @doc """
  Helper function to get the redirect path after login.

  ## Examples

      iex> get_redirect_after_login(conn)
      "/movies"

      iex> get_redirect_after_login(conn)
      "/"

  """
  def get_redirect_after_login(conn) do
    get_session(conn, :redirect_after_login) || "/"
  end

  @doc """
  Helper function to clear the redirect path after successful redirect.

  ## Examples

      iex> clear_redirect_after_login(conn)
      %Plug.Conn{}

  """
  def clear_redirect_after_login(conn) do
    delete_session(conn, :redirect_after_login)
  end
end
