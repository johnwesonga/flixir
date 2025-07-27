defmodule FlixirWeb.MainNavigationTest do
  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FlixirWeb.MainNavigation

  describe "main_nav/1" do
    test "renders navigation with login button when not authenticated" do
      assigns = %{
        current_section: :search,
        current_subsection: nil,
        current_user: nil,
        authenticated?: false
      }

      html = render_component(&main_nav/1, assigns)

      assert html =~ "Flixir"
      assert html =~ "Search"
      assert html =~ "Movies"
      assert html =~ "Reviews"
      assert html =~ "Login"
      refute html =~ "user-menu"
    end

    test "renders navigation with user menu when authenticated" do
      user_data = %{
        "username" => "testuser",
        "name" => "Test User"
      }

      assigns = %{
        current_section: :movies,
        current_subsection: nil,
        current_user: user_data,
        authenticated?: true
      }

      html = render_component(&main_nav/1, assigns)

      assert html =~ "Flixir"
      assert html =~ "Search"
      assert html =~ "Movies"
      assert html =~ "Reviews"
      assert html =~ "testuser"
      assert html =~ "user-menu"
      refute html =~ "Login"
    end

    test "highlights current section" do
      assigns = %{
        current_section: :movies,
        current_subsection: nil,
        current_user: nil,
        authenticated?: false
      }

      html = render_component(&main_nav/1, assigns)

      assert html =~ "main-nav-movies"
      assert html =~ "bg-blue-50 text-blue-700"
    end
  end

  describe "user_menu/1" do
    test "renders user menu with username and logout option" do
      user_data = %{
        "username" => "testuser",
        "name" => "Test User"
      }

      assigns = %{current_user: user_data}

      html = render_component(&user_menu/1, assigns)

      assert html =~ "testuser"
      assert html =~ "Test User"
      assert html =~ "Logout"
      assert html =~ "/auth/logout"
    end

    test "renders user menu with only username when name is empty" do
      user_data = %{
        "username" => "testuser",
        "name" => ""
      }

      assigns = %{current_user: user_data}

      html = render_component(&user_menu/1, assigns)

      assert html =~ "testuser"
      refute html =~ "Test User"
      assert html =~ "Logout"
    end
  end

  describe "login_button/1" do
    test "renders login button with correct link" do
      assigns = %{}

      html = render_component(&login_button/1, assigns)

      assert html =~ "Login"
      assert html =~ "/auth/login"
    end
  end
end
