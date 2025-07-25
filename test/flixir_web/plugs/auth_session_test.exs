defmodule FlixirWeb.Plugs.AuthSessionTest do
  use FlixirWeb.ConnCase, async: true
  import Mock

  alias FlixirWeb.Plugs.AuthSession
  alias Flixir.Auth
  alias Flixir.Auth.Session

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
    test "assigns unauthenticated state when no session ID in cookie" do
      conn = build_conn(:get, "/")
      opts = AuthSession.init([])

      conn = AuthSession.call(conn, opts)

      assert conn.assigns.current_user == nil
      assert conn.assigns.current_session == nil
      assert conn.assigns.authenticated? == false
    end

    test "does not redirect when authentication not required" do
      conn = build_conn(:get, "/")
      opts = AuthSession.init(require_auth: false)

      conn = AuthSession.call(conn, opts)

      refute conn.halted
      assert conn.assigns.authenticated? == false
    end

    test "redirects to login when authentication required" do
      conn = build_conn(:get, "/protected")
      opts = AuthSession.init(require_auth: true)

      conn = AuthSession.call(conn, opts)

      assert conn.halted
      assert redirected_to(conn) == "/auth/login"
      assert get_session(conn, :redirect_after_login) == "/protected"
    end

    test "redirects to custom path when specified" do
      conn = build_conn(:get, "/admin")
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

    test "assigns authenticated state for valid session", %{session: session, user_data: user_data} do
      with_mocks([
        {Auth, [], [
          validate_session: fn "tmdb_session_123" -> {:ok, session} end,
          get_current_user: fn "tmdb_session_123" -> {:ok, user_data} end
        ]}
      ]) do
        conn =
          build_conn(:get, "/")
          |> init_test_session(%{})
          |> put_session("tmdb_session_id", "tmdb_session_123")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == user_data
        assert conn.assigns.current_session == session
        assert conn.assigns.authenticated? == true
        refute conn.halted
      end
    end

    test "allows access to protected routes when authenticated", %{session: session, user_data: user_data} do
      with_mocks([
        {Auth, [], [
          validate_session: fn "tmdb_session_123" -> {:ok, session} end,
          get_current_user: fn "tmdb_session_123" -> {:ok, user_data} end
        ]}
      ]) do
        conn =
          build_conn(:get, "/protected")
          |> init_test_session(%{})
          |> put_session("tmdb_session_id", "tmdb_session_123")

        opts = AuthSession.init(require_auth: true)
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.authenticated? == true
        refute conn.halted
      end
    end
  end

  describe "call/2 with expired session" do
    test "clears expired session and assigns unauthenticated state" do
      with_mock Auth, [validate_session: fn "expired_session" -> {:error, :session_expired} end] do
        conn =
          build_conn(:get, "/")
          |> init_test_session(%{})
          |> put_session("tmdb_session_id", "expired_session")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == nil
        assert conn.assigns.current_session == nil
        assert conn.assigns.authenticated? == false
        assert get_session(conn, "tmdb_session_id") == nil
      end
    end

    test "redirects to login for expired session on protected route" do
      with_mock Auth, [validate_session: fn "expired_session" -> {:error, :session_expired} end] do
        conn =
          build_conn(:get, "/protected")
          |> init_test_session(%{})
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
    test "clears invalid session and assigns unauthenticated state" do
      with_mock Auth, [validate_session: fn "invalid_session" -> {:error, :not_found} end] do
        conn =
          build_conn(:get, "/")
          |> init_test_session(%{})
          |> put_session("tmdb_session_id", "invalid_session")

        opts = AuthSession.init([])
        conn = AuthSession.call(conn, opts)

        assert conn.assigns.current_user == nil
        assert conn.assigns.current_session == nil
        assert conn.assigns.authenticated? == false
        assert get_session(conn, "tmdb_session_id") == nil
      end
    end

    test "handles user data retrieval failure" do
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
        conn =
          build_conn(:get, "/")
          |> init_test_session(%{})
          |> put_session("tmdb_session_id", "tmdb_session_123")

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
    test "put_session_id/2 stores session ID in cookie" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})

      conn = AuthSession.put_session_id(conn, "new_session_123")

      assert get_session(conn, "tmdb_session_id") == "new_session_123"
    end

    test "clear_session_id/1 removes session ID from cookie" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_session("tmdb_session_id", "session_to_clear")

      conn = AuthSession.clear_session_id(conn)

      assert get_session(conn, "tmdb_session_id") == nil
    end

    test "get_redirect_after_login/1 returns stored redirect path" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_session(:redirect_after_login, "/intended/path")

      redirect_path = AuthSession.get_redirect_after_login(conn)

      assert redirect_path == "/intended/path"
    end

    test "get_redirect_after_login/1 returns default when no redirect stored" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})

      redirect_path = AuthSession.get_redirect_after_login(conn)

      assert redirect_path == "/"
    end

    test "clear_redirect_after_login/1 removes redirect path" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_session(:redirect_after_login, "/some/path")

      conn = AuthSession.clear_redirect_after_login(conn)

      assert get_session(conn, :redirect_after_login) == nil
    end
  end

  describe "edge cases" do
    test "handles non-binary session ID gracefully" do
      conn =
        build_conn(:get, "/")
        |> init_test_session(%{})
        |> put_session("tmdb_session_id", 12345)  # Non-binary value

      opts = AuthSession.init([])
      conn = AuthSession.call(conn, opts)

      assert conn.assigns.current_user == nil
      assert conn.assigns.current_session == nil
      assert conn.assigns.authenticated? == false
      assert get_session(conn, "tmdb_session_id") == nil
    end

    test "handles Auth context errors gracefully" do
      with_mock Auth, [validate_session: fn "error_session" -> {:error, :database_error} end] do
        conn =
          build_conn(:get, "/")
          |> init_test_session(%{})
          |> put_session("tmdb_session_id", "error_session")

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
