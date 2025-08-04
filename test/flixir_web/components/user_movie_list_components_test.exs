defmodule FlixirWeb.UserMovieListComponentsTest do
  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import FlixirWeb.UserMovieListComponents

  describe "user_lists_container/1" do
    test "renders empty state when no lists" do
      assigns = %{
        lists: [],
        loading: false,
        error: nil,
        current_user: %{id: 1}
      }

      html = render_component(&user_lists_container/1, assigns)

      assert html =~ "My Movie Lists"
      assert html =~ "Create New List"
      assert html =~ "No movie lists yet"
      assert html =~ "Create Your First List"
    end

    test "renders loading state" do
      assigns = %{
        lists: [],
        loading: true,
        error: nil,
        current_user: %{id: 1}
      }

      html = render_component(&user_lists_container/1, assigns)

      assert html =~ "Loading your lists..."
      assert html =~ "skeleton-list-card"
    end

    test "renders error state" do
      assigns = %{
        lists: [],
        loading: false,
        error: "Network error",
        current_user: %{id: 1}
      }

      html = render_component(&user_lists_container/1, assigns)

      assert html =~ "Something went wrong"
      assert html =~ "Network error"
      assert html =~ "Try Again"
    end

    test "renders lists grid when lists present" do
      list = %{
        id: "123",
        name: "My Watchlist",
        description: "Movies to watch",
        is_public: false,
        updated_at: DateTime.utc_now(),
        list_items: [%{id: "item1"}, %{id: "item2"}]
      }

      assigns = %{
        lists: [list],
        loading: false,
        error: nil,
        current_user: %{id: 1}
      }

      html = render_component(&user_lists_container/1, assigns)

      assert html =~ "My Watchlist"
      assert html =~ "Movies to watch"
      assert html =~ "2 movies"
    end
  end

  describe "list_card/1" do
    test "renders list card with basic information" do
      list = %{
        id: "123",
        name: "My Watchlist",
        description: "Movies to watch",
        is_public: false,
        updated_at: DateTime.utc_now(),
        list_items: [%{id: "item1"}, %{id: "item2"}]
      }

      assigns = %{list: list}
      html = render_component(&list_card/1, assigns)

      assert html =~ "My Watchlist"
      assert html =~ "Movies to watch"
      assert html =~ "2 movies"
      assert html =~ "Private"
      assert html =~ "View List"
      assert html =~ "Edit"
      assert html =~ "Clear"
      assert html =~ "Delete"
    end

    test "renders public list correctly" do
      list = %{
        id: "123",
        name: "Public List",
        description: "A public list",
        is_public: true,
        updated_at: DateTime.utc_now(),
        list_items: []
      }

      assigns = %{list: list}
      html = render_component(&list_card/1, assigns)

      assert html =~ "Public List"
      assert html =~ "Public"
      assert html =~ "0 movies"
      refute html =~ "Clear"  # Clear button should not show for empty lists
    end

    test "renders list without description" do
      list = %{
        id: "123",
        name: "Simple List",
        description: nil,
        is_public: false,
        updated_at: DateTime.utc_now(),
        list_items: []
      }

      assigns = %{list: list}
      html = render_component(&list_card/1, assigns)

      assert html =~ "Simple List"
      refute html =~ "description"
    end
  end

  describe "list_form/1" do
    test "renders create form" do
      form = to_form(%{}, as: :list)

      assigns = %{
        form: form,
        action: :create,
        title: "Create New List"
      }

      html = render_component(&list_form/1, assigns)

      assert html =~ "Create New List"
      assert html =~ "Create a new movie list"
      assert html =~ "List Name"
      assert html =~ "Description (Optional)"
      assert html =~ "Make this list public"
      assert html =~ "Create List"
      assert html =~ "Cancel"
    end

    test "renders edit form" do
      form = to_form(%{}, as: :list)

      assigns = %{
        form: form,
        action: :edit,
        title: "Edit List"
      }

      html = render_component(&list_form/1, assigns)

      assert html =~ "Edit List"
      assert html =~ "Update your list details"
      assert html =~ "Update List"
    end
  end

  describe "list_stats/1" do
    test "renders compact stats" do
      stats = %{
        movie_count: 5,
        is_public: true,
        updated_at: DateTime.utc_now()
      }

      assigns = %{stats: stats, compact: true}
      html = render_component(&list_stats/1, assigns)

      assert html =~ "5 movies"
      assert html =~ "Public"
    end

    test "renders full stats" do
      stats = %{
        movie_count: 10,
        is_public: false,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      assigns = %{stats: stats, compact: false}
      html = render_component(&list_stats/1, assigns)

      assert html =~ "List Statistics"
      assert html =~ "10"
      assert html =~ "Movies"
      assert html =~ "Private"
      assert html =~ "Created:"
      assert html =~ "Last updated:"
    end
  end

  describe "delete_confirmation_modal/1" do
    test "renders delete confirmation modal" do
      list = %{
        id: "123",
        name: "Test List",
        list_items: [%{id: "item1"}, %{id: "item2"}]
      }

      assigns = %{show: true, list: list}
      html = render_component(&delete_confirmation_modal/1, assigns)

      assert html =~ "Delete List"
      assert html =~ "Test List"
      assert html =~ "2 movies"
      assert html =~ "Cancel"
      assert html =~ "Delete List"
    end

    test "does not render when show is false" do
      list = %{
        id: "123",
        name: "Test List",
        list_items: []
      }

      assigns = %{show: false, list: list}
      html = render_component(&delete_confirmation_modal/1, assigns)

      refute html =~ "Delete List"
    end
  end

  describe "clear_confirmation_modal/1" do
    test "renders clear confirmation modal" do
      list = %{
        id: "123",
        name: "Test List",
        list_items: [%{id: "item1"}, %{id: "item2"}, %{id: "item3"}]
      }

      assigns = %{show: true, list: list}
      html = render_component(&clear_confirmation_modal/1, assigns)

      assert html =~ "Clear List"
      assert html =~ "Test List"
      assert html =~ "all 3 movies"
      assert html =~ "Cancel"
      assert html =~ "Clear List"
    end
  end

  describe "add_to_list_selector/1" do
    test "renders empty state when no lists" do
      assigns = %{
        show: true,
        lists: [],
        movie_id: 550
      }

      html = render_component(&add_to_list_selector/1, assigns)

      assert html =~ "Add to List"
      assert html =~ "You don't have any lists yet"
      assert html =~ "Create Your First List"
    end

    test "renders list selection when lists available" do
      lists = [
        %{
          id: "123",
          name: "Watchlist",
          description: "Movies to watch",
          is_public: false,
          list_items: [%{id: "item1"}]
        },
        %{
          id: "456",
          name: "Favorites",
          description: nil,
          is_public: true,
          list_items: []
        }
      ]

      assigns = %{
        show: true,
        lists: lists,
        movie_id: 550
      }

      html = render_component(&add_to_list_selector/1, assigns)

      assert html =~ "Add to List"
      assert html =~ "Watchlist"
      assert html =~ "Movies to watch"
      assert html =~ "1 movies"
      assert html =~ "Favorites"
      assert html =~ "0 movies"
      assert html =~ "Create New List"
    end
  end

  describe "helper functions" do
    test "format_relative_date/1 formats dates correctly" do
      now = DateTime.utc_now()
      yesterday = DateTime.add(now, -1, :day)
      _last_week = DateTime.add(now, -7, :day)
      _last_month = DateTime.add(now, -30, :day)
      _last_year = DateTime.add(now, -365, :day)

      # Test through private function access via component rendering
      list_today = %{
        id: "1", name: "Today", description: nil, is_public: false,
        updated_at: now, list_items: []
      }

      list_yesterday = %{
        id: "2", name: "Yesterday", description: nil, is_public: false,
        updated_at: yesterday, list_items: []
      }

      html_today = render_component(&list_card/1, %{list: list_today})
      html_yesterday = render_component(&list_card/1, %{list: list_yesterday})

      assert html_today =~ "today"
      assert html_yesterday =~ "yesterday"
    end
  end
end
