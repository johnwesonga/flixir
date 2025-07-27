defmodule FlixirWeb.DebugAuthTest do
  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "debug authentication state" do
    test "check what assigns are available in LiveView", %{conn: conn} do
      # Simulate the full AuthSession plug behavior
      user_data = %{"username" => "testuser", "id" => 123}
      session_data = %{id: "test-session", username: "testuser"}

      conn =
        conn
        |> init_test_session(%{"tmdb_session_id" => "test-session-123"})
        |> assign(:current_user, user_data)
        |> assign(:current_session, session_data)
        |> assign(:authenticated?, true)

      {:ok, view, html} = live(conn, "/")

      # Let's see what's in the HTML
      IO.puts("=== HTML OUTPUT ===")
      IO.puts(html)

      # Check if login button is present
      login_present = String.contains?(html, "data-testid=\"login-button\"")
      user_menu_present = String.contains?(html, "data-testid=\"user-menu\"")

      IO.puts("=== DEBUG INFO ===")
      IO.puts("Login button present: #{login_present}")
      IO.puts("User menu present: #{user_menu_present}")
      IO.puts("HTML contains 'testuser': #{String.contains?(html, "testuser")}")

      # This test is just for debugging, so we'll always pass
      assert true
    end
  end
end
