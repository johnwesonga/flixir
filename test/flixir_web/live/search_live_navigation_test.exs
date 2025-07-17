defmodule FlixirWeb.SearchLiveNavigationTest do
  @moduledoc """
  Integration tests for search routing and navigation functionality.

  Tests cover:
  - Route accessibility and basic rendering
  - URL parameter handling for shareable search links
  - Navigation link functionality
  - Breadcrumb navigation
  - Page title updates
  """

  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Media
  alias Flixir.Media.SearchResult

  # Sample results for mocking
  @sample_results [
    %SearchResult{
      id: 1,
      title: "Batman",
      media_type: :movie,
      release_date: ~D[2022-03-04],
      overview: "Batman ventures into Gotham City's underworld.",
      poster_path: "/batman.jpg",
      genre_ids: [28, 80, 18],
      vote_average: 8.0,
      popularity: 100.0
    },
    %SearchResult{
      id: 2,
      title: "Batman: The Animated Series",
      media_type: :tv,
      release_date: ~D[1992-09-05],
      overview: "Batman fights crime in Gotham City.",
      poster_path: "/batman_series.jpg",
      genre_ids: [16, 10759],
      vote_average: 8.5,
      popularity: 80.0
    }
  ]

  # Remove the global setup block - mocking will be done per test

  describe "search route" do
    test "GET /search renders search page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      assert html =~ "Search Movies &amp; TV Shows"
      assert html =~ "Discover your next favorite movie or TV series"
      assert html =~ "Search for movies and TV shows..."
    end

    test "search page has correct page title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")

      assert page_title(view) =~ "Search"
    end

    test "search page displays breadcrumb navigation", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      # Check for breadcrumb navigation
      assert html =~ "aria-label=\"Breadcrumb\""
      assert html =~ "hero-home"
      assert html =~ "hero-chevron-right"
      assert html =~ "Search"
    end
  end

  describe "URL parameter handling" do
    test "handles search query parameter", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, html} = live(conn, ~p"/search?q=batman")

        # Should display the search query in the input
        assert html =~ "value=\"batman\""

        # Should update page title
        assert page_title(view) =~ "Search: batman"

        # Should show search results header
        assert html =~ "Search Results for &quot;batman&quot;"

        # Should show query in breadcrumb
        assert html =~ "batman"
      end
    end

    test "handles media type filter parameter", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, _view, html} = live(conn, ~p"/search?q=batman&type=movie")

        # Should select the movie option
        assert html =~ "selected=\"selected\">Movies</option>"

        # Should show active filter badge
        assert html =~ "Movie"
        assert html =~ "active-filter-badge"
      end
    end

    test "handles sort parameter", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, _view, html} = live(conn, ~p"/search?q=batman&sort=popularity")

        # Should select the popularity sort option
        assert html =~ "selected=\"selected\">Popularity</option>"

        # Should show active sort badge
        assert html =~ "Popularity"
        assert html =~ "active-sort-badge"
      end
    end

    test "handles page parameter", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman&page=2")

        # Should set the page in the socket assigns
        assert view |> element("[data-testid=search-input]") |> render() =~ "batman"
      end
    end

    test "handles multiple parameters together", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, html} = live(conn, ~p"/search?q=batman&type=movie&sort=popularity&page=2")

        # Should handle all parameters
        assert html =~ "value=\"batman\""
        assert html =~ "selected=\"selected\">Movies</option>"
        assert html =~ "selected=\"selected\">Popularity</option>"
        assert page_title(view) =~ "Search: batman"
      end
    end

    test "ignores invalid parameters gracefully", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, html} = live(conn, ~p"/search?q=batman&type=invalid&sort=invalid&page=invalid")

        # Should use default values for invalid parameters
        assert html =~ "value=\"batman\""
        assert html =~ "selected=\"selected\">All</option>"
        assert html =~ "selected=\"selected\">Relevance</option>"
        assert page_title(view) =~ "Search: batman"
      end
    end
  end

  describe "navigation integration" do
    test "search page renders correctly", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      # Should render the search page
      assert html =~ "Search Movies &amp; TV Shows"
      assert html =~ "Discover your next favorite movie or TV series"
    end

    test "breadcrumb home link exists", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, _view, html} = live(conn, ~p"/search?q=batman")

        # Should have home breadcrumb link
        assert html =~ "href=\"/\""
        assert html =~ "hero-home"
      end
    end

    test "breadcrumb search link exists when query is present", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, _view, html} = live(conn, ~p"/search?q=batman")

        # Should have search breadcrumb link when query is present
        assert html =~ "href=\"/search\""
        assert html =~ "Search"
      end
    end
  end

  describe "breadcrumb navigation" do
    test "shows basic breadcrumb without query", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      # Should show: Home > Search
      assert html =~ "hero-home"
      assert html =~ "hero-chevron-right"
      assert html =~ "Search"

      # Should not show query breadcrumb
      refute html =~ "truncate max-w-xs"
    end

    test "shows full breadcrumb with query", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, _view, html} = live(conn, ~p"/search?q=batman")

        # Should show: Home > Search > batman
        assert html =~ "hero-home"
        assert html =~ "hero-chevron-right"
        assert html =~ "Search"
        assert html =~ "batman"
        assert html =~ "truncate max-w-xs"
      end
    end

    test "breadcrumb query is truncated for long queries", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        long_query = String.duplicate("a", 100)
        {:ok, _view, html} = live(conn, ~p"/search?q=#{long_query}")

        # Should show truncated query with title attribute
        assert html =~ "truncate max-w-xs"
        assert html =~ "title=\"#{long_query}\""
      end
    end

    test "breadcrumb updates when search is cleared", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        # Clear the search
        view |> element("[data-testid=clear-search-button]") |> render_click()

        html = render(view)

        # Should not show query in breadcrumb
        refute html =~ "batman"
        refute html =~ "truncate max-w-xs"
        assert html =~ "Search"
      end
    end
  end

  describe "page title updates" do
    test "page title updates with search query", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Perform a search
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Page title should update
        assert page_title(view) =~ "Search: batman"
      end
    end

    test "page title resets when search is cleared", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        # Clear the search
        view |> element("[data-testid=clear-search-button]") |> render_click()

        # Page title should reset
        assert page_title(view) =~ "Search"
        refute page_title(view) =~ "batman"
      end
    end

    test "page title updates when URL parameters change", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Simulate URL parameter change by performing a search
        view
        |> form("#search-form", search: %{query: "superman"})
        |> render_submit()

        # Page title should update
        assert page_title(view) =~ "Search: superman"
      end
    end
  end

  describe "URL updates during search interactions" do
    test "URL updates when performing search", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Perform a search
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Should update URL with query parameter
        assert_patch(view, ~p"/search?q=batman")
      end
    end

    test "URL updates when changing filters", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        # Change media type filter
        view
        |> form("[data-testid=filter-sort-controls] form", filters: %{media_type: "movie"})
        |> render_change()

        # Should update URL with filter parameter
        assert_patch(view, ~p"/search?q=batman&type=movie")
      end
    end

    test "URL updates when changing sort", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        # Change sort option
        view
        |> form("[data-testid=filter-sort-controls] form", filters: %{sort_by: "popularity"})
        |> render_change()

        # Should update URL with sort parameter
        assert_patch(view, ~p"/search?q=batman&sort=popularity")
      end
    end

    test "URL clears parameters when search is cleared", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman&type=movie&sort=popularity")

        # Clear the search
        view |> element("[data-testid=clear-search-button]") |> render_click()

        # Should reset URL to base search path
        assert_patch(view, ~p"/search")
      end
    end
  end

  describe "shareable search links" do
    test "can share search link with query", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        # Simulate someone sharing a search link
        {:ok, _view, html} = live(conn, ~p"/search?q=batman")

        # Should load with the shared search query
        assert html =~ "value=\"batman\""
        assert html =~ "Search Results for &quot;batman&quot;"
      end
    end

    test "can share search link with filters", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        # Simulate someone sharing a filtered search link
        {:ok, _view, html} = live(conn, ~p"/search?q=batman&type=movie&sort=popularity")

        # Should load with all shared parameters
        assert html =~ "value=\"batman\""
        assert html =~ "selected=\"selected\">Movies</option>"
        assert html =~ "selected=\"selected\">Popularity</option>"
      end
    end

    test "shared links work with page parameter", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        # Simulate someone sharing a paginated search link
        {:ok, _view, html} = live(conn, ~p"/search?q=batman&page=2")

        # Should load with the correct page and query
        assert html =~ "value=\"batman\""
        assert html =~ "Search Results for &quot;batman&quot;"
      end
    end
  end

  describe "error handling in navigation" do
    test "handles malformed URL parameters gracefully", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        # Test with malformed parameters
        {:ok, view, html} = live(conn, ~p"/search?q=batman&type=&sort=&page=")

        # Should handle gracefully with defaults
        assert html =~ "value=\"batman\""
        assert html =~ "selected=\"selected\">All</option>"
        assert html =~ "selected=\"selected\">Relevance</option>"
        assert page_title(view) =~ "Search: batman"
      end
    end

    test "handles special characters in search query URLs", %{conn: conn} do
      with_mock Media, [search_content: fn _query, _opts -> {:ok, @sample_results} end] do
        query = "batman & robin"
        encoded_query = URI.encode_query(%{"q" => query})

        {:ok, view, html} = live(conn, "/search?" <> encoded_query)

        # Should handle special characters correctly (HTML encoded in the input)
        assert html =~ "value=\"batman &amp; robin\""
        # Page title also gets HTML encoded
        assert page_title(view) =~ "Search: batman &amp; robin"
      end
    end
  end
end
