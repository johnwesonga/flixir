defmodule FlixirWeb.Plugs.AuthSessionTest do
  use FlixirWeb.ConnCase, async: true
  import Mock

  alias FlixirWeb.Plugs.AuthSession
  alias Flixir.Auth
  alias Flixir.Auth.Session

  setup %{conn: conn} do
    # Set up session configuration for testing
    conn =
      conn
      |> Map.put(:secret_key_base, String.duplicate("a", 64))
      |> Plug.Session.call(Plug.Session.init(
        store: :cookie,
        key: "_test_key",
        signing_salt: "test_salt",
        encryption_salt: "test_encrypt_salt"
      ))
      |> fetch_session()

    %{conn: conn}
  end

  describe "init/1" do
    test "returns default options" do
      opts = AuthSession.init([])
      assert opts.require_auth == false
      assert opts.redirect_to == "/auth/login"
    end

    test "accepts custom options" do
      opts = AuthSession.init(require_auth: true, redirect_to: "/custom/login")
      assert opts.require_auth == true
      assert opts.redirect_to == "/custom/login"
    end
  end

  describe "call/2 with no session" do
    test "assigns unauthenticated state when no session ID in cookie", %{conn: conn} do
      opts = AuthSession.init([])

      conn = AuthSession.call(conn, opts)

      assert conn.assigns.current_user == nil
      assert conn.assigns.current_session == nil
      assert conn.assigns.authenticated? == false
    end

    test "does not redirect when authentication not required", %{conn: conn} do
      opts = AuthSession.init(require_auth: false)

      conn = AuthSession.call(conn, opts)

      refute conn.halted
      assert conn.assigns.authenticated? == false
    end

    test "redirects to login when authentication required", %{conn: conn} do
      conn = %{conn | request_path: "/protected"}
      opts = AuthSession.init(require_auth: true)

      conn = AuthSession.call(conn, opts)

      assert conn.halted
      assert redirected_to(conn) == "/auth/login"
      assert get_session(conn, :redirect_after_login) == "/protected"
    end

    test "redirects to custom path when specified", %{conn: conn} do
      conn = %{conn | request_path: "/admin"}
      opts = AuthSession.init(require_auth: true, redirect_to: "/admin/login")

      conn = AuthSession.call(conn, opts)

      assert conn.halted
      assert redirected_to(conn) == "/admin/login"
    end
  end

  describe "call/2 with valid session" do
    setup do
      session = %Session{
        id: "uuid-123",
        tmdb_session_id: "tmdb_session_123",
        tmdb_user_id: 12345,
        username: "testuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        last_accessed_at: DateTime.utc_now()
      }

      user_data = %{
        "id" => 12345,
        "username" => "testuser",
        "name" => "Test User"
      }

      {:ok, session: session, user_data: user_data}
    end

    test "assigns authenticated state for valid session", %{conn: conn, session: session, user_data: user_data} do
      with_mocks([
        {Auth, [], [
          validate_session: fn "tmdb_session_123" -> {:ok, session} end,
          get_current_user: fn "tmdb_session_123" -> {:ok, user_data} end
        ]}
      ]) do
        conn = put_session(conn, "tmdb_session_id", "tmdb_session_123")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == user_data
        assert conn.assigns.current_session == session
        assert conn.assigns.authenticated? == true
        refute conn.halted
      end
    end

    test "allows access to protected routes when authenticated", %{conn: conn, session: session, user_data: user_data} do
      with_mocks([
        {Auth, [], [
          validate_session: fn "tmdb_session_123" -> {:ok, session} end,
          get_current_user: fn "tmdb_session_123" -> {:ok, user_data} end
        ]}
      ]) do
        conn =
          conn
          |> Map.put(:request_path, "/protected")
          |> put_session("tmdb_session_id", "tmdb_session_123")

        opts = AuthSession.init(require_auth: true)
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.authenticated? == true
        refute conn.halted
      end
    end
  end

  describe "call/2 with expired session" do
    test "clears expired session and assigns unauthenticated state", %{conn: conn} do
      with_mock Auth, [validate_session: fn "expired_session" -> {:error, :session_expired} end] do
        conn = put_session(conn, "tmdb_session_id", "expired_session")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == nil
        assert conn.assigns.current_session == nil
        assert conn.assigns.authenticated? == false
        assert get_session(conn, "tmdb_session_id") == nil
      end
    end

    test "redirects to login for expired session on protected route", %{conn: conn} do
      with_mock Auth, [validate_session: fn "expired_session" -> {:error, :session_expired} end] do
        conn =
          conn
          |> Map.put(:request_path, "/protected")
          |> put_session("tmdb_session_id", "expired_session")

        opts = AuthSession.init(require_auth: true)
        conn = AuthSession.call(conn, opts)

        assert conn.halted
        assert redirected_to(conn) == "/auth/login"
        assert get_session(conn, "tmdb_session_id") == nil
      end
    end
  end

  describe "call/2 with invalid session" do
    test "clears invalid session and assigns unauthenticated state", %{conn: conn} do
      with_mock Auth, [validate_session: fn "invalid_session" -> {:error, :not_found} end] do
        conn = put_session(conn, "tmdb_session_id", "invalid_session")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == nil
        assert conn.assigns.current_session == nil
        assert conn.assigns.authenticated? == false
        assert get_session(conn, "tmdb_session_id") == nil
      end
    end

    test "handles user data retrieval failure", %{conn: conn} do
      session = %Session{
        id: "uuid-123",
        tmdb_session_id: "tmdb_session_123",
        tmdb_user_id: 12345,
        username: "testuser"
      }

      with_mocks([
        {Auth, [], [
          validate_session: fn "tmdb_session_123" -> {:ok, session} end,
          get_current_user: fn "tmdb_session_123" -> {:error, :api_error} end
        ]}
      ]) do
        conn = put_session(conn, "tmdb_session_id", "tmdb_session_123")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == nil
        assert conn.assigns.current_session == nil
        assert conn.assigns.authenticated? == false
        assert get_session(conn, "tmdb_session_id") == nil
      end
    end
  end

  describe "helper functions" do
    test "put_session_id/2 stores session ID in encrypted format", %{conn: conn} do
      conn = AuthSession.put_session_id(conn, "new_session_123")

      # Should not store in plain session key
      assert get_session(conn, "tmdb_session_id") == nil

      # Should store in encrypted format
      encrypted_data = get_session(conn, "encrypted_session_data")
      assert is_map(encrypted_data)
      assert encrypted_data.session_id == "new_session_123"
    end

    test "clear_session_id/1 removes session ID from cookie", %{conn: conn} do
      conn =
        conn
        |> put_session("tmdb_session_id", "session_to_clear")
        |> AuthSession.put_session_id("encrypted_session")

      conn = AuthSession.clear_session_id(conn)

      assert get_session(conn, "tmdb_session_id") == nil
      assert get_session(conn, "encrypted_session_data") == nil
    end

    test "get_redirect_after_login/1 returns stored redirect path", %{conn: conn} do
      conn = put_session(conn, :redirect_after_login, "/intended/path")

      redirect_path = AuthSession.get_redirect_after_login(conn)

      assert redirect_path == "/intended/path"
    end

    test "get_redirect_after_login/1 returns default when no redirect stored", %{conn: conn} do
      redirect_path = AuthSession.get_redirect_after_login(conn)

      assert redirect_path == "/"
    end

    test "clear_redirect_after_login/1 removes redirect path", %{conn: conn} do
      conn =
        conn
        |> put_session(:redirect_after_login, "/some/path")
        |> AuthSession.clear_redirect_after_login()

      assert get_session(conn, :redirect_after_login) == nil
    end
  end

  describe "edge cases" do
    test "handles non-binary session ID gracefully", %{conn: conn} do
      conn = put_session(conn, "tmdb_session_id", 12345)  # Non-binary value

      opts = AuthSession.init([])
      conn = AuthSession.call(conn, opts)

      assert conn.assigns.current_user == nil
      assert conn.assigns.current_session == nil
      assert conn.assigns.authenticated? == false
      assert get_session(conn, "tmdb_session_id") == nil
    end

    test "handles Auth context errors gracefully", %{conn: conn} do
      with_mock Auth, [validate_session: fn "error_session" -> {:error, :database_error} end] do
        conn = put_session(conn, "tmdb_session_id", "error_session")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == nil
        assert conn.assigns.current_session == nil
        assert conn.assigns.authenticated? == false
        assert get_session(conn, "tmdb_session_id") == nil
      end
    end
  end
end
