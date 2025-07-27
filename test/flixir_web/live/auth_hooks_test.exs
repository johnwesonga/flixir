defmodule FlixirWeb.AuthHooksTest do
  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  describe "AuthHooks authentication state" do
    test "unauthenticated user has correct state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Should show login button, not user menu
      assert html =~ "data-testid=\"login-button\""
      refute html =~ "data-testid=\"user-menu\""
    end

    test "authenticated user with valid session has correct state", %{conn: conn} do
      user_data = %{
        "id" => 123,
        "username" => "testuser",
        "name" => "Test User"
      }

      session_data = %{
        id: "test-session-id",
        tmdb_session_id: "tmdb-session-123",
        tmdb_user_id: 123,
        username: "testuser"
      }

      # Mock the Auth context functions
      with_mocks([
        {Flixir.Auth, [], [
          validate_session: fn "tmdb-session-123" -> {:ok, session_data} end,
          get_current_user: fn "tmdb-session-123" -> {:ok, user_data} end
        ]}
      ]) do
        # Set up the session to simulate what would happen after successful login
        conn =
          conn
          |> init_test_session(%{"tmdb_session_id" => "tmdb-session-123"})

        {:ok, _view, html} = live(conn, "/")

        # Should show user menu, not login button
        assert html =~ "data-testid=\"user-menu\""
        assert html =~ "testuser"
        refute html =~ "data-testid=\"login-button\""
      end
    end

    test "user with invalid session shows unauthenticated state", %{conn: conn} do
      # Mock the Auth context to return an error
      with_mocks([
        {Flixir.Auth, [], [
          validate_session: fn "invalid-session" -> {:error, :not_found} end
        ]}
      ]) do
        conn =
          conn
          |> init_test_session(%{"tmdb_session_id" => "invalid-session"})

        {:ok, _view, html} = live(conn, "/")

        # Should show login button, not user menu
        assert html =~ "data-testid=\"login-button\""
        refute html =~ "data-testid=\"user-menu\""
      end
    end
  end
end
