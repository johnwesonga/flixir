defmodule FlixirWeb.Plugs.AuthSessionSecurityTest do
  use FlixirWeb.ConnCase, async: true

  alias FlixirWeb.Plugs.AuthSession
  alias Flixir.Auth

  setup %{conn: conn} do
    # Set up session configuration for testing
    conn =
      conn
      |> Plug.Session.call(Plug.Session.init(
        store: :cookie,
        key: "_test_key",
        signing_salt: "test_salt",
        encryption_salt: "test_encrypt_salt"
      ))
      |> fetch_session()

    %{conn: conn}
  end

  describe "encrypted session storage" do
    test "put_session_id/2 stores session data in encrypted format", %{conn: conn} do
      session_id = "test_session_123"

      conn = AuthSession.put_session_id(conn, session_id)

      # Should not store in plain session key
      assert get_session(conn, "tmdb_session_id") == nil

      # Should store in encrypted format
      encrypted_data = get_session(conn, "encrypted_session_data")
      assert is_map(encrypted_data)
      assert encrypted_data.session_id == session_id
      assert is_integer(encrypted_data.created_at)
      assert is_binary(encrypted_data.csrf_token)
    end

    test "clear_session_id/1 removes both plain and encrypted session data", %{conn: conn} do
      # Set up both types of session data
      conn =
        conn
        |> put_session("tmdb_session_id", "plain_session")
        |> AuthSession.put_session_id("encrypted_session")

      # Clear session
      conn = AuthSession.clear_session_id(conn)

      # Both should be cleared
      assert get_session(conn, "tmdb_session_id") == nil
      assert get_session(conn, "encrypted_session_data") == nil
    end

    test "encrypted session data expires after max age", %{conn: conn} do
      # Create session data with old timestamp
      old_timestamp = DateTime.utc_now() |> DateTime.add(-90000, :second) |> DateTime.to_unix()

      old_session_data = %{
        session_id: "old_session",
        created_at: old_timestamp,
        csrf_token: "old_csrf_token"
      }

      conn = put_session(conn, "encrypted_session_data", old_session_data)

      # Should not validate old session data
      conn = AuthSession.call(conn, %{require_auth: false, redirect_to: "/auth/login"})

      assert conn.assigns.authenticated? == false
      assert conn.assigns.current_user == nil
    end
  end

  describe "CSRF protection" do
    test "validate_csrf_token/2 validates CSRF tokens correctly", %{conn: conn} do
      # Test with Phoenix CSRF token when no session exists

      csrf_token = Phoenix.Controller.get_csrf_token()
      assert AuthSession.validate_csrf_token(conn, csrf_token) == :ok

      # Test with invalid token
      assert AuthSession.validate_csrf_token(conn, "invalid_token") == {:error, :invalid_csrf_token}
    end

    test "validate_csrf_token/2 validates against stored CSRF token when session exists", %{conn: conn} do
      # Create session with CSRF token
      conn = AuthSession.put_session_id(conn, "test_session")
      encrypted_data = get_session(conn, "encrypted_session_data")
      stored_csrf_token = encrypted_data.csrf_token

      # Should validate with stored token
      assert AuthSession.validate_csrf_token(conn, stored_csrf_token) == :ok

      # Should reject different token
      assert AuthSession.validate_csrf_token(conn, "different_token") == {:error, :invalid_csrf_token}
    end
  end

  describe "session timeout and idle detection" do
    setup do
      # Create a test session in the database
      session_attrs = %{
        tmdb_session_id: "timeout_test_session",
        tmdb_user_id: 12345,
        username: "timeoutuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        last_accessed_at: DateTime.utc_now()
      }

      {:ok, session} = Auth.create_session(session_attrs)
      %{session: session}
    end

    test "session_active?/1 detects expired sessions", %{session: session} do
      # Update session to be expired
      expired_session = %{session | expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)}

      refute Auth.session_active?(expired_session)
    end

    test "session_active?/1 detects idle sessions", %{session: session} do
      # Update session to be idle (last accessed more than 2 hours ago)
      idle_session = %{session | last_accessed_at: DateTime.add(DateTime.utc_now(), -7300, :second)}

      refute Auth.session_active?(idle_session)
    end

    test "session_active?/1 validates active sessions", %{session: session} do
      # Session should be active (not expired and not idle)
      assert Auth.session_active?(session)
    end
  end

  describe "session security configuration" do
    test "session configuration includes security flags" do
      config = Application.get_env(:flixir, FlixirWeb.Endpoint)[:session]

      assert config[:http_only] == true
      assert config[:same_site] in ["Lax", "Strict"]
      assert is_integer(config[:max_age])
      assert is_binary(config[:signing_salt])
      assert is_binary(config[:encryption_salt])
    end
  end
end
