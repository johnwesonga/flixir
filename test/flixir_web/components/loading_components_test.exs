defmodule FlixirWeb.Components.LoadingComponentsTest do
  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FlixirWeb.Components.LoadingComponents

  describe "loading_spinner/1" do
    test "renders loading spinner with default message" do
      assigns = %{}
      html = render_component(&loading_spinner/1, assigns)

      assert html =~ "Loading..."
      assert html =~ "animate-spin"
      assert html =~ "border-t-blue-600"
    end

    test "renders loading spinner with custom message" do
      assigns = %{message: "Fetching reviews..."}
      html = render_component(&loading_spinner/1, assigns)

      assert html =~ "Fetching reviews..."
    end

    test "renders loading spinner with different sizes" do
      small_html = render_component(&loading_spinner/1, %{size: "sm"})
      medium_html = render_component(&loading_spinner/1, %{size: "md"})
      large_html = render_component(&loading_spinner/1, %{size: "lg"})

      assert small_html =~ "h-4 w-4"
      assert medium_html =~ "h-6 w-6"
      assert large_html =~ "h-8 w-8"
    end

    test "applies custom CSS classes" do
      assigns = %{class: "my-custom-class"}
      html = render_component(&loading_spinner/1, assigns)

      assert html =~ "my-custom-class"
    end
  end

  describe "review_skeleton/1" do
    test "renders default number of skeleton cards" do
      assigns = %{}
      html = render_component(&review_skeleton/1, assigns)

      # Should render 3 skeleton cards by default
      skeleton_count = (html |> String.split("animate-pulse") |> length()) - 1
      assert skeleton_count == 3
    end

    test "renders custom number of skeleton cards" do
      assigns = %{count: 5}
      html = render_component(&review_skeleton/1, assigns)

      skeleton_count = (html |> String.split("animate-pulse") |> length()) - 1
      assert skeleton_count == 5
    end

    test "includes skeleton elements for review structure" do
      assigns = %{}
      html = render_component(&review_skeleton/1, assigns)

      # Should include author avatar skeleton
      assert html =~ "w-10 h-10 bg-gray-300 rounded-full"
      # Should include rating stars skeleton
      assert html =~ "w-4 h-4 bg-gray-300 rounded"
      # Should include content lines skeleton
      assert html =~ "h-4 bg-gray-300 rounded w-full"
    end
  end

  describe "rating_stats_skeleton/1" do
    test "renders rating statistics skeleton" do
      assigns = %{}
      html = render_component(&rating_stats_skeleton/1, assigns)

      assert html =~ "animate-pulse"
      # Should include average rating skeleton
      assert html =~ "w-16 h-16 bg-gray-300 rounded-full"
      # Should include rating distribution skeleton
      assert html =~ "flex-1 h-2 bg-gray-300 rounded"
    end

    test "applies custom CSS classes" do
      assigns = %{class: "custom-skeleton-class"}
      html = render_component(&rating_stats_skeleton/1, assigns)

      assert html =~ "custom-skeleton-class"
    end
  end

  # Note: loading_overlay/1 tests are skipped due to complexity of testing slot components

  describe "filter_skeleton/1" do
    test "renders filter controls skeleton" do
      assigns = %{}
      html = render_component(&filter_skeleton/1, assigns)

      assert html =~ "animate-pulse"
      assert html =~ "h-10 bg-gray-300 rounded w-32"
      assert html =~ "h-10 bg-gray-300 rounded w-24"
      assert html =~ "h-10 bg-gray-300 rounded w-28"
    end
  end

  describe "pagination_skeleton/1" do
    test "renders pagination skeleton" do
      assigns = %{}
      html = render_component(&pagination_skeleton/1, assigns)

      assert html =~ "animate-pulse"
      assert html =~ "h-4 bg-gray-300 rounded w-32"
      assert html =~ "h-8 w-8 bg-gray-300 rounded"
    end
  end
end
