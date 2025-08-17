defmodule FlixirWeb.UserMovieListComponentsIntegrationTest do
  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import FlixirWeb.UserMovieListComponents

  describe "component integration" do
    test "user_lists_container with list_card integration" do
      lists = [
        %{
          "id" => "123",
          "name" => "Action Movies",
          "description" => "High-octane action films",
          "public" => true,
          "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "item_count" => 3
        },
        %{
          "id" => "456",
          "name" => "Comedies",
          "description" => nil,
          "public" => false,
          "updated_at" => DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.to_iso8601(),
          "item_count" => 1
        }
      ]

      assigns = %{
        lists: lists,
        loading: false,
        error: nil,
        current_user: %{id: 1}
      }

      html = render_component(&user_lists_container/1, assigns)

      # Check container structure
      assert html =~ "My Movie Lists"
      assert html =~ "Create New List"
      assert html =~ "lists-grid"

      # Check first list card
      assert html =~ "Action Movies"
      assert html =~ "High-octane action films"
      assert html =~ "3 movies"
      assert html =~ "Public"

      # Check second list card
      assert html =~ "Comedies"
      assert html =~ "1 movie"
      assert html =~ "Private"

      # Check action buttons are present
      assert html =~ "View List"
      refute html =~ "Edit"  # Edit button should not be present
      assert html =~ "Clear"
      assert html =~ "Delete"
    end

    test "form and modal components work with proper data flow" do
      list = %{
        "id" => "123",
        "name" => "Test List",
        "description" => "A test list",
        "public" => false,
        "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "item_count" => 2
      }

      # Test create form component
      form = to_form(%{"name" => "", "description" => "", "is_public" => false}, as: :list)
      form_assigns = %{form: form, sync_status: :synced}
      form_html = render_component(&create_list_form/1, form_assigns)

      assert form_html =~ "Create New List"
      assert form_html =~ "Create List"

      # Test delete modal
      delete_assigns = %{show: true, list: list}
      delete_html = render_component(&delete_confirmation_modal/1, delete_assigns)

      assert delete_html =~ "Delete TMDB List"
      assert delete_html =~ "Test List"
      assert delete_html =~ "2 movies"

      # Test clear modal
      clear_assigns = %{show: true, list: list}
      clear_html = render_component(&clear_confirmation_modal/1, clear_assigns)

      assert clear_html =~ "Clear TMDB List"
      assert clear_html =~ "all 2 movies"
    end

    test "add_to_list_selector with various list states" do
      # Test with empty lists
      empty_assigns = %{show: true, lists: [], movie_id: 550}
      empty_html = render_component(&add_to_list_selector/1, empty_assigns)

      assert empty_html =~ "You don't have any lists yet"
      assert empty_html =~ "Create Your First List"

      # Test with populated lists
      lists = [
        %{
          tmdb_list_id: "123",
          name: "Watchlist",
          description: "Movies to watch later",
          is_public: false,
          list_items: [%{id: "item1"}]
        },
        %{
          tmdb_list_id: "456",
          name: "Favorites",
          description: "",
          is_public: true,
          list_items: []
        }
      ]

      populated_assigns = %{show: true, lists: lists, movie_id: 550}
      populated_html = render_component(&add_to_list_selector/1, populated_assigns)

      assert populated_html =~ "Watchlist"
      assert populated_html =~ "Movies to watch later"
      assert populated_html =~ "1 movies"
      assert populated_html =~ "Favorites"
      assert populated_html =~ "0 movies"
      assert populated_html =~ "Create New List"
    end

    test "list_stats component in different modes" do
      stats = %{
        movie_count: 15,
        is_public: true,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Test compact mode
      compact_assigns = %{stats: stats, compact: true}
      compact_html = render_component(&list_stats/1, compact_assigns)

      assert compact_html =~ "15 movies"
      assert compact_html =~ "Public"
      refute compact_html =~ "List Statistics"

      # Test full mode
      full_assigns = %{stats: stats, compact: false}
      full_html = render_component(&list_stats/1, full_assigns)

      assert full_html =~ "List Statistics"
      assert full_html =~ "15"
      assert full_html =~ "Movies"
      assert full_html =~ "Public"
      assert full_html =~ "Created:"
      assert full_html =~ "Last updated:"
    end

    test "responsive behavior and accessibility features" do
      list = %{
        id: "123",
        name: "Accessible List",
        description: "Testing accessibility",
        is_public: false,
        updated_at: DateTime.utc_now(),
        list_items: []
      }

      # Test individual list card accessibility
      card_assigns = %{list: list}
      card_html = render_component(&list_card/1, card_assigns)

      # Check for proper ARIA attributes and semantic HTML
      assert card_html =~ "data-testid=\"list-card\""

      assert card_html =~ "data-testid=\"delete-list-button\""

      # Test grid container responsive classes
      grid_assigns = %{lists: [list]}
      grid_html = render_component(&lists_grid/1, grid_assigns)

      # Check for responsive classes in grid
      assert grid_html =~ "sm:grid-cols-2"
      assert grid_html =~ "lg:grid-cols-3"
      assert grid_html =~ "xl:grid-cols-4"
    end
  end
end
