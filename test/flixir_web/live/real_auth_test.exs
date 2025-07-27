defmodule FlixirWeb.RealAuthTest do
  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  describe "real authentication flow" do
    test "authentication works with mocked Auth context", %{conn: conn} do
      user_data = %{
        "id" => 123,
        "username" => "testuser",
        "name" => "Test User"
      }

      session = %{
        id: "test-session-id",
        tmdb_session_id: "tmdb-session-123",
        tmdb_user_id: 123,
        username: "testuser"
      }

      # Mock the Auth context functions
      with_mocks([
        {Flixir.Auth, [], [
          validate_session: fn "tmdb-session-123" -> {:ok, session} end,
          get_current_user: fn "tmdb-session-123" -> {:ok, user_data} end
        ]}
      ]) do
        # Set up the session in the connection to trigger the AuthSession plug
        conn =
          conn
          |> init_test_session(%{"tmdb_session_id" => "tmdb-session-123"})

        # Make a regular GET request to trigger the full pipeline
        conn = get(conn, "/")

        # Check if the response contains the user menu
        html = html_response(conn, 200)

        IO.puts("=== REAL AUTH TEST HTML ===")
        IO.puts(html)

        login_present = String.contains?(html, "data-testid=\"login-button\"")
        user_menu_present = String.contains?(html, "data-testid=\"user-menu\"")

        IO.puts("=== REAL AUTH DEBUG INFO ===")
        IO.puts("Login button present: #{login_present}")
        IO.puts("User menu present: #{user_menu_present}")
        IO.puts("HTML contains 'testuser': #{String.contains?(html, "testuser")}")

        # This should show the user menu instead of login button
        refute login_present, "Login button should not be present when authenticated"
        assert user_menu_present, "User menu should be present when authenticated"
        assert String.contains?(html, "testuser"), "Username should be displayed"
      end
    end
  end
end
