defmodule FlixirWeb.AuthLiveTest do
  use FlixirWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Auth
  alias Flixir.Auth.Session

  describe "login page" do
    test "displays login form when not authenticated", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/auth/login")

      assert html =~ "Sign in to your account"
      assert html =~ "Sign in with TMDB"
      assert has_element?(view, "button[phx-click='login']")
    end

    test "redirects to home when already authenticated", %{conn: conn} do
      session = %Session{
        id: "test-id",
        tmdb_session_id: "test-session",
        tmdb_user_id: 123,
        username: "testuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      }

      user_data = %{
        "id" => 123,
        "username" => "testuser",
        "name" => "Test User"
      }

      conn =
        conn
        |> assign(:current_user, user_data)
        |> assign(:current_session, session)
        |> assign(:authenticated?, true)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/auth/login")
    end

    test "handles login button click", %{conn: conn} do
      with_mock Auth, start_authentication: fn -> {:ok, "https://tmdb.org/auth"} end do
        {:ok, view, _html} = live(conn, ~p"/auth/login")

        # Click login button should start authentication
        render_click(view, "login")

        # Should show loading state
        assert render(view) =~ "Connecting to TMDB..."
        assert has_element?(view, "button[disabled]")

        # Should eventually redirect to TMDB
        assert_redirect(view, "https://tmdb.org/auth")
      end
    end

    test "displays error message when authentication fails", %{conn: conn} do
      with_mock Auth, start_authentication: fn -> {:error, :token_creation_failed} end do
        {:ok, view, _html} = live(conn, ~p"/auth/login")

        render_click(view, "login")

        # Wait for async operation to complete
        :timer.sleep(100)

        html = render(view)
        assert html =~ "Authentication Error"
        assert html =~ "Unable to connect to TMDB"
        assert has_element?(view, "button[phx-click='retry_login']")
      end
    end

    test "retry login clears error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/auth/login")

      # Set error state
      send(view.pid, {:assign, :error_message, "Test error"})
      assert render(view) =~ "Test error"

      # Click retry
      render_click(view, "retry_login")

      # Error should be cleared
      refute render(view) =~ "Test error"
    end
  end

  describe "callback page" do
    test "displays loading state during authentication", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/auth/callback?request_token=test_token")

      assert html =~ "Completing Sign In"
      assert html =~ "Please wait while we complete"
      assert has_element?(view, ".animate-spin")
    end

    test "handles successful authentication callback", %{conn: conn} do
      session = %Session{
        id: "test-id",
        tmdb_session_id: "test-session",
        tmdb_user_id: 123,
        username: "testuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      }

      with_mock Auth, complete_authentication: fn "test_token" -> {:ok, session} end do
        {:ok, view, _html} = live(conn, ~p"/auth/callback?request_token=test_token")

        # Wait for async operation to complete
        :timer.sleep(100)

        # Should redirect to store session
        assert_redirect(view, "/auth/store_session?session_id=test-session&redirect_to=/")
      end
    end

    test "handles authentication failure in callback", %{conn: conn} do
      with_mock Auth, complete_authentication: fn "invalid_token" -> {:error, :invalid_token} end do
        {:ok, view, _html} = live(conn, ~p"/auth/callback?request_token=invalid_token")

        # Wait for async operation to complete
        :timer.sleep(100)

        html = render(view)
        assert html =~ "Authentication Failed"
        assert html =~ "Invalid authentication token"
        assert has_element?(view, "a[href='/auth/login']")
      end
    end

    test "handles denied authentication", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/auth/callback?denied=true")

      assert html =~ "Authentication was cancelled"
      assert html =~ "Please try again"
    end

    test "handles invalid callback parameters", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/auth/callback")

      assert html =~ "Invalid authentication callback"
      assert html =~ "Please try logging in again"
    end
  end

  describe "logout page" do
    test "displays logout confirmation when authenticated", %{conn: conn} do
      session = %Session{
        id: "test-id",
        tmdb_session_id: "test-session",
        tmdb_user_id: 123,
        username: "testuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      }

      user_data = %{
        "id" => 123,
        "username" => "testuser",
        "name" => "Test User"
      }

      conn =
        conn
        |> assign(:current_user, user_data)
        |> assign(:current_session, session)
        |> assign(:authenticated?, true)

      {:ok, view, html} = live(conn, ~p"/auth/logout")

      assert html =~ "Sign Out"
      assert html =~ "Are you sure you want to sign out, testuser?"
      assert has_element?(view, "button[phx-click='confirm_logout']")
      assert has_element?(view, "button[phx-click='cancel_logout']")
    end

    test "displays not authenticated message when not logged in", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/auth/logout")

      assert html =~ "You are not currently signed in"
      assert has_element?(view, "a[href='/auth/login']")
    end

    test "handles logout confirmation", %{conn: conn} do
      session = %Session{
        id: "test-id",
        tmdb_session_id: "test-session",
        tmdb_user_id: 123,
        username: "testuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      }

      user_data = %{
        "id" => 123,
        "username" => "testuser",
        "name" => "Test User"
      }

      conn =
        conn
        |> assign(:current_user, user_data)
        |> assign(:current_session, session)
        |> assign(:authenticated?, true)

      with_mock Auth, logout: fn "test-session" -> :ok end do
        {:ok, view, _html} = live(conn, ~p"/auth/logout")

        render_click(view, "confirm_logout")

        # Should show loading state
        assert render(view) =~ "Signing out..."

        # Wait for async operation to complete
        :timer.sleep(100)

        # Should redirect to clear session
        assert_redirect(view, "/auth/clear_session")
      end
    end

    test "handles cancel logout", %{conn: conn} do
      session = %Session{
        id: "test-id",
        tmdb_session_id: "test-session",
        tmdb_user_id: 123,
        username: "testuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      }

      user_data = %{
        "id" => 123,
        "username" => "testuser",
        "name" => "Test User"
      }

      conn =
        conn
        |> assign(:current_user, user_data)
        |> assign(:current_session, session)
        |> assign(:authenticated?, true)

      {:ok, view, _html} = live(conn, ~p"/auth/logout")

      render_click(view, "cancel_logout")

      assert_redirect(view, "/")
    end

    test "handles logout when not authenticated", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/auth/logout")

      render_click(view, "logout")

      assert_redirect(view, "/")
    end
  end

  describe "error handling" do
    test "formats different error types correctly", %{conn: conn} do
      error_cases = [
        {:token_creation_failed, "Unable to connect to TMDB"},
        {:session_creation_failed, "Failed to create authentication session"},
        {:invalid_token, "Invalid authentication token"},
        {:unauthorized, "Authentication failed"},
        {:timeout, "Authentication request timed out"},
        {:rate_limited, "Too many authentication attempts"},
        {:not_found, "Authentication service not found"},
        {{:transport_error, :nxdomain}, "Network error during authentication"},
        {{:unexpected_status, 500},
         "Authentication service returned an unexpected response (500)"},
        {:unknown_error, "An unexpected error occurred during authentication"}
      ]

      Enum.each(error_cases, fn {error, expected_message} ->
        with_mock Auth, start_authentication: fn -> {:error, error} end do
          {:ok, view, _html} = live(conn, ~p"/auth/login")

          render_click(view, "login")

          # Wait for async operation to complete
          :timer.sleep(100)

          html = render(view)
          assert html =~ expected_message
        end
      end)
    end
  end
end
