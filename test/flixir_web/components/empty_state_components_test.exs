defmodule FlixirWeb.Components.EmptyStateComponentsTest do
  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FlixirWeb.Components.EmptyStateComponents

  describe "no_reviews_empty_state/1" do
    test "renders default empty state" do
      assigns = %{}
      html = render_component(&no_reviews_empty_state/1, assigns)

      assert html =~ "No reviews yet"
      assert html =~ "Be the first to share your thoughts"
      assert html =~ "hero-chat-bubble-left-ellipsis"
    end

    test "renders custom title and description" do
      assigns = %{
        title: "Custom Title",
        description: "Custom description text"
      }
      html = render_component(&no_reviews_empty_state/1, assigns)

      assert html =~ "Custom Title"
      assert html =~ "Custom description text"
    end

    test "renders action button when provided" do
      assigns = %{
        action_text: "Write Review",
        action_href: "/reviews/new"
      }
      html = render_component(&no_reviews_empty_state/1, assigns)

      assert html =~ "Write Review"
      assert html =~ "/reviews/new"
    end

    test "does not render action button when not provided" do
      assigns = %{}
      html = render_component(&no_reviews_empty_state/1, assigns)

      refute html =~ "href="
    end
  end

  describe "no_filtered_results_empty_state/1" do
    test "renders filtered results empty state" do
      assigns = %{}
      html = render_component(&no_filtered_results_empty_state/1, assigns)

      assert html =~ "No reviews match your filters"
      assert html =~ "adjusting your search criteria"
      assert html =~ "hero-funnel"
    end

    test "shows clear filters button when filters are applied" do
      assigns = %{filters_applied: true}
      html = render_component(&no_filtered_results_empty_state/1, assigns)

      assert html =~ "Clear filters"
      assert html =~ "phx-click=\"clear-filters\""
    end

    test "hides clear filters button when no filters applied" do
      assigns = %{filters_applied: false}
      html = render_component(&no_filtered_results_empty_state/1, assigns)

      refute html =~ "Clear filters"
    end

    test "uses custom clear filters event" do
      assigns = %{
        filters_applied: true,
        clear_filters_event: "custom-clear"
      }
      html = render_component(&no_filtered_results_empty_state/1, assigns)

      assert html =~ "phx-click=\"custom-clear\""
    end
  end

  describe "no_ratings_empty_state/1" do
    test "renders no ratings empty state" do
      assigns = %{}
      html = render_component(&no_ratings_empty_state/1, assigns)

      assert html =~ "Not yet rated"
      assert html =~ "No ratings available"
      assert html =~ "hero-star"
    end
  end

  describe "error_state/1" do
    test "renders error state with required description" do
      assigns = %{description: "Something went wrong with the request"}
      html = render_component(&error_state/1, assigns)

      assert html =~ "Something went wrong"
      assert html =~ "Something went wrong with the request"
      assert html =~ "hero-exclamation-triangle"
    end

    test "renders custom title" do
      assigns = %{
        title: "Custom Error",
        description: "Error description"
      }
      html = render_component(&error_state/1, assigns)

      assert html =~ "Custom Error"
    end

    test "renders retry button when event provided" do
      assigns = %{
        description: "Error occurred",
        retry_event: "retry-action"
      }
      html = render_component(&error_state/1, assigns)

      assert html =~ "Try again"
      assert html =~ "phx-click=\"retry-action\""
    end

    test "does not render retry button when no event provided" do
      assigns = %{description: "Error occurred"}
      html = render_component(&error_state/1, assigns)

      refute html =~ "Try again"
      refute html =~ "phx-click="
    end

    test "uses custom retry text" do
      assigns = %{
        description: "Error occurred",
        retry_event: "retry",
        retry_text: "Retry Now"
      }
      html = render_component(&error_state/1, assigns)

      assert html =~ "Retry Now"
    end
  end

  describe "network_error_state/1" do
    test "renders network error state" do
      assigns = %{}
      html = render_component(&network_error_state/1, assigns)

      assert html =~ "Connection problem"
      assert html =~ "connection issues"
      assert html =~ "internet connection"
      assert html =~ "hero-wifi"
    end

    test "uses custom retry event" do
      assigns = %{retry_event: "custom-retry"}
      html = render_component(&network_error_state/1, assigns)

      assert html =~ "phx-click=\"custom-retry\""
    end
  end

  describe "service_error_state/1" do
    test "renders service error state" do
      assigns = %{}
      html = render_component(&service_error_state/1, assigns)

      assert html =~ "Service temporarily unavailable"
      assert html =~ "currently unavailable"
      assert html =~ "hero-server"
    end
  end

  describe "rate_limit_error_state/1" do
    test "renders rate limit error state" do
      assigns = %{}
      html = render_component(&rate_limit_error_state/1, assigns)

      assert html =~ "Too many requests"
      assert html =~ "wait a moment"
      assert html =~ "hero-clock"
    end

    test "does not include retry button" do
      assigns = %{}
      html = render_component(&rate_limit_error_state/1, assigns)

      refute html =~ "Try again"
      refute html =~ "phx-click="
    end
  end

  describe "compact_empty_state/1" do
    test "renders compact empty state" do
      assigns = %{}
      html = render_component(&compact_empty_state/1, assigns)

      assert html =~ "No data available"
      assert html =~ "hero-document"
    end

    test "renders custom message and icon" do
      assigns = %{
        message: "No items found",
        icon: "hero-folder"
      }
      html = render_component(&compact_empty_state/1, assigns)

      assert html =~ "No items found"
      assert html =~ "folder"
    end
  end
end
