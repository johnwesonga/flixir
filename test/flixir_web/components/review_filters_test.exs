defmodule FlixirWeb.ReviewFiltersTest do
  @moduledoc """
  Tests for review filtering and sorting components.
  """

  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FlixirWeb.ReviewFilters

  describe "review_filters/1" do
    test "renders basic filter controls" do
      filters = %{
        sort_by: :date,
        sort_order: :desc,
        filter_by_rating: nil,
        author_filter: nil,
        content_filter: nil
      }

      html = render_component(&review_filters/1, %{
        filters: filters,
        on_filter_change: "update_filters",
        total_reviews: 10,
        filtered_count: 10
      })

      assert html =~ "Filter & Sort Reviews"
      assert html =~ "Sort by"
      assert html =~ "Rating"
      assert html =~ "Author"
      assert html =~ "Content"
      assert html =~ "Showing all 10 reviews"
    end

    test "shows active filter count when filters are applied" do
      filters = %{
        sort_by: :rating,
        sort_order: :asc,
        filter_by_rating: :positive,
        author_filter: "John",
        content_filter: nil
      }

      html = render_component(&review_filters/1, %{
        filters: filters,
        on_filter_change: "update_filters",
        total_reviews: 20,
        filtered_count: 5
      })

      assert html =~ "4 active"
      assert html =~ "Showing 5 of 20 reviews"
      assert html =~ "Clear all"
    end

    test "shows filtered count when different from total" do
      filters = %{
        sort_by: :date,
        sort_order: :desc,
        filter_by_rating: :positive,
        author_filter: nil,
        content_filter: nil
      }

      html = render_component(&review_filters/1, %{
        filters: filters,
        on_filter_change: "update_filters",
        total_reviews: 50,
        filtered_count: 25
      })

      assert html =~ "Showing 25 of 50 reviews"
    end

    test "hides clear all button when no active filters" do
      filters = %{
        sort_by: :date,
        sort_order: :desc,
        filter_by_rating: nil,
        author_filter: nil,
        content_filter: nil
      }

      html = render_component(&review_filters/1, %{
        filters: filters,
        on_filter_change: "update_filters",
        total_reviews: 10,
        filtered_count: 10
      })

      refute html =~ "Clear all"
      refute html =~ "active"
    end
  end

  describe "sort_control/1" do
    test "renders sort dropdown with current selection" do
      html = render_component(&sort_control/1, %{
        current_sort: :rating,
        current_order: :asc,
        on_change: "update_filters"
      })

      assert html =~ ~s(value="rating" selected)
      assert html =~ "hero-arrow-up"
    end

    test "shows descending arrow for desc order" do
      html = render_component(&sort_control/1, %{
        current_sort: :date,
        current_order: :desc,
        on_change: "update_filters"
      })

      assert html =~ "hero-arrow-down"
    end

    test "includes all sort options" do
      html = render_component(&sort_control/1, %{
        current_sort: :date,
        current_order: :desc,
        on_change: "update_filters"
      })

      assert html =~ ~s(value="date")
      assert html =~ ~s(value="rating")
      assert html =~ ~s(value="author")
    end
  end

  describe "rating_filter/1" do
    test "renders rating filter dropdown" do
      html = render_component(&rating_filter/1, %{
        current_filter: nil,
        on_change: "update_filters"
      })

      assert html =~ "All ratings"
      assert html =~ "Positive (6+ stars)"
      assert html =~ "Negative (&lt; 6 stars)"
      assert html =~ "High (8-10 stars)"
      assert html =~ "Medium (5-7 stars)"
      assert html =~ "Low (1-4 stars)"
    end

    test "shows current selection" do
      html = render_component(&rating_filter/1, %{
        current_filter: :positive,
        on_change: "update_filters"
      })

      assert html =~ ~s(value="positive" selected)
    end

    test "handles tuple rating filters" do
      html = render_component(&rating_filter/1, %{
        current_filter: {8, 10},
        on_change: "update_filters"
      })

      assert html =~ ~s(value="high" selected)
    end
  end

  describe "author_filter/1" do
    test "renders author input field" do
      html = render_component(&author_filter/1, %{
        current_filter: nil,
        on_change: "update_filters"
      })

      assert html =~ ~s(name="author_filter")
      assert html =~ "Filter by author name..."
      assert html =~ ~s(phx-debounce="300")
    end

    test "shows current filter value" do
      html = render_component(&author_filter/1, %{
        current_filter: "John Doe",
        on_change: "update_filters"
      })

      assert html =~ ~s(value="John Doe")
    end

    test "shows clear button when filter is active" do
      html = render_component(&author_filter/1, %{
        current_filter: "John",
        on_change: "update_filters"
      })

      assert html =~ "hero-x-mark"
      assert html =~ "clear-author-filter"
    end

    test "hides clear button when no filter" do
      html = render_component(&author_filter/1, %{
        current_filter: nil,
        on_change: "update_filters"
      })

      refute html =~ "clear-author-filter"
    end
  end

  describe "content_filter/1" do
    test "renders content input field" do
      html = render_component(&content_filter/1, %{
        current_filter: nil,
        on_change: "update_filters"
      })

      assert html =~ ~s(name="content_filter")
      assert html =~ "Search review content..."
      assert html =~ ~s(phx-debounce="300")
    end

    test "shows current filter value" do
      html = render_component(&content_filter/1, %{
        current_filter: "great movie",
        on_change: "update_filters"
      })

      assert html =~ ~s(value="great movie")
    end

    test "shows clear button when filter is active" do
      html = render_component(&content_filter/1, %{
        current_filter: "amazing",
        on_change: "update_filters"
      })

      assert html =~ "hero-x-mark"
      assert html =~ "clear-content-filter"
    end
  end

  describe "active_filters_display/1" do
    test "renders active filter tags" do
      filters = %{
        sort_by: :rating,
        sort_order: :asc,
        filter_by_rating: :positive,
        author_filter: "John Doe",
        content_filter: "great"
      }

      html = render_component(&active_filters_display/1, %{
        filters: filters,
        on_remove: "update_filters"
      })

      assert html =~ "Active Filters"
      assert html =~ "Sort: Rating ↑"
      assert html =~ "Rating: Positive"
      assert html =~ "Author: John Doe"
      assert html =~ "Content: great"
    end

    test "handles long filter values by truncating" do
      filters = %{
        sort_by: :date,
        sort_order: :desc,
        filter_by_rating: nil,
        author_filter: "This is a very long author name that should be truncated",
        content_filter: "This is a very long content filter that should also be truncated"
      }

      html = render_component(&active_filters_display/1, %{
        filters: filters,
        on_remove: "update_filters"
      })

      assert html =~ "Author: This is a very long "
      assert html =~ "Content: This is a very long "
    end

    test "includes remove buttons for each filter" do
      filters = %{
        sort_by: :rating,
        sort_order: :desc,
        filter_by_rating: :negative,
        author_filter: nil,
        content_filter: nil
      }

      html = render_component(&active_filters_display/1, %{
        filters: filters,
        on_remove: "update_filters"
      })

      assert html =~ "remove-filter-clear_sort"
      assert html =~ "remove-filter-clear_rating"
    end
  end

  describe "helper functions" do
    test "count_active_filters/1 counts non-default filters" do
      # No active filters (all defaults)
      filters = %{
        sort_by: :date,
        sort_order: :desc,
        filter_by_rating: nil,
        author_filter: nil,
        content_filter: nil
      }
      assert FlixirWeb.ReviewFilters.count_active_filters(filters) == 0

      # Some active filters
      filters = %{
        sort_by: :rating,
        sort_order: :asc,
        filter_by_rating: :positive,
        author_filter: "John",
        content_filter: nil
      }
      # This is a public function, so we can test it directly
      assert FlixirWeb.ReviewFilters.count_active_filters(filters) == 4
    end

    test "filter_present?/1 detects present filters" do
      # This is tested indirectly through the component behavior
      filters_with_empty_string = %{
        sort_by: :date,
        sort_order: :desc,
        filter_by_rating: nil,
        author_filter: "",
        content_filter: "   "
      }

      html = render_component(&review_filters/1, %{
        filters: filters_with_empty_string,
        on_filter_change: "update_filters",
        total_reviews: 10,
        filtered_count: 10
      })

      # Should not show active filters for empty/whitespace strings
      refute html =~ "active"
    end

    test "build_active_filter_tags/1 creates proper tags" do
      filters = %{
        sort_by: :rating,
        sort_order: :desc,
        filter_by_rating: {5, 7},
        author_filter: "Test Author",
        content_filter: "test content"
      }

      html = render_component(&active_filters_display/1, %{
        filters: filters,
        on_remove: "update_filters"
      })

      assert html =~ "Sort: Rating ↓"
      assert html =~ "Rating: Medium (5-7)"
      assert html =~ "Author: Test Author"
      assert html =~ "Content: test content"
    end

    test "format_rating_filter_label/1 handles all rating types" do
      test_cases = [
        {:positive, "Positive"},
        {:negative, "Negative"},
        {{8, 10}, "High (8-10)"},
        {{5, 7}, "Medium (5-7)"},
        {{1, 4}, "Low (1-4)"},
        {:unknown, "Custom"}
      ]

      for {filter, expected_label} <- test_cases do
        filters = %{
          sort_by: :date,
          sort_order: :desc,
          filter_by_rating: filter,
          author_filter: nil,
          content_filter: nil
        }

        html = render_component(&active_filters_display/1, %{
          filters: filters,
          on_remove: "update_filters"
        })

        assert html =~ "Rating: #{expected_label}"
      end
    end
  end
end
