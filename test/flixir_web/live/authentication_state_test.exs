defmodule FlixirWeb.AuthenticationStateTest do
  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "authentication state in LiveViews" do
    test "unauthenticated user sees login button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Login"
      assert html =~ "data-testid=\"login-button\""
      refute html =~ "data-testid=\"user-menu\""
    end

    test "authentication state is properly initialized by on_mount hook", %{conn: conn} do
      # This test verifies that the on_mount hook properly sets default authentication state
      # by checking that the login button is shown (indicating authenticated? is false)
      {:ok, _view, html} = live(conn, "/")

      # The presence of the login button indicates that authenticated? is false
      assert html =~ "data-testid=\"login-button\""
      # The absence of user menu indicates that current_user is nil
      refute html =~ "data-testid=\"user-menu\""
    end
  end
end
