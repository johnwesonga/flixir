defmodule FlixirWeb.SearchLiveTest do
  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Media
  alias Flixir.Media.SearchResult

  @sample_results [
    %SearchResult{
      id: 1,
      title: "The Dark Knight",
      media_type: :movie,
      release_date: ~D[2008-07-18],
      overview: "Batman raises the stakes in his war on crime.",
      poster_path: "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
      genre_ids: [28, 80, 18],
      vote_average: 9.0,
      popularity: 123.456
    },
    %SearchResult{
      id: 2,
      title: "Breaking Bad",
      media_type: :tv,
      release_date: ~D[2008-01-20],
      overview: "A high school chemistry teacher turned meth cook.",
      poster_path: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
      genre_ids: [18, 80],
      vote_average: 9.5,
      popularity: 234.567
    }
  ]

  describe "mount/3" do
    test "initializes with default state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      assert html =~ "Search Movies &amp; TV Shows"
      assert html =~ "Discover Movies &amp; TV Shows"
    end
  end

  describe "search functionality" do
    test "performs search when form is submitted", %{conn: conn} do
      with_mock Media, [search_content: fn("batman", _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, "[data-testid='search-result-card']", "The Dark Knight")
        assert has_element?(view, "[data-testid='search-result-card']", "Breaking Bad")
        assert called(Media.search_content("batman", :_))
      end
    end

    test "handles empty search query", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")

      html = view
      |> form("#search-form", search: %{query: ""})
      |> render_submit()

      refute has_element?(view, "[data-testid='search-result-card']")

      # Check for the text in the rendered HTML
      assert html =~ "Discover Movies &amp; TV Shows"
    end

    test "displays error message for search failures", %{conn: conn} do
      with_mock Media, [search_content: fn(_query, _opts) ->
        {:error, {:timeout, "Search request timed out. Please try again."}}
      end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, ".bg-red-50", "Search request timed out. Please try again.")
        assert called(Media.search_content("batman", :_))
      end
    end

    test "displays no results message when search returns empty", %{conn: conn} do
      with_mock Media, [search_content: fn(_query, _opts) -> {:ok, []} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "nonexistent"})
        |> render_submit()

        assert has_element?(view, "h3", "No results found")
        assert called(Media.search_content("nonexistent", :_))
      end
    end
  end

  describe "filtering functionality" do
    test "filters by movie type", %{conn: conn} do
      with_mock Media, [search_content: fn("batman", _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        view
        |> element("select[name='media_type']")
        |> render_change(%{media_type: "movie"})

        assert has_element?(view, "select[name='media_type'] option[value='movie'][selected]")
      end
    end

    test "filters by TV show type", %{conn: conn} do
      with_mock Media, [search_content: fn("batman", _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        view
        |> element("select[name='media_type']")
        |> render_change(%{media_type: "tv"})

        assert has_element?(view, "select[name='media_type'] option[value='tv'][selected]")
      end
    end
  end

  describe "sorting functionality" do
    test "sorts by popularity", %{conn: conn} do
      with_mock Media, [search_content: fn("batman", _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        view
        |> element("select[name='sort_by']")
        |> render_change(%{sort_by: "popularity"})

        assert has_element?(view, "select[name='sort_by'] option[value='popularity'][selected]")
      end
    end

    test "sorts by title", %{conn: conn} do
      with_mock Media, [search_content: fn("batman", _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        view
        |> element("select[name='sort_by']")
        |> render_change(%{sort_by: "title"})

        assert has_element?(view, "select[name='sort_by'] option[value='title'][selected]")
      end
    end
  end

  describe "clear search functionality" do
    test "clears search when clear button is clicked", %{conn: conn} do
      with_mock Media, [search_content: fn(_query, _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        # Should show clear search button
        assert has_element?(view, "button", "Clear search")

        # Click clear search
        view
        |> element("button", "Clear search")
        |> render_click()

        # Should clear the search
        refute has_element?(view, "[data-testid='search-result-card']")
        assert has_element?(view, "input[value='']")
      end
    end
  end

  describe "result display" do
    test "displays search results with correct information", %{conn: conn} do
      with_mock Media, [search_content: fn(_query, _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        # Check movie result
        assert has_element?(view, "[data-testid='search-result-card']", "The Dark Knight")
        assert has_element?(view, ".bg-blue-100", "Movie")
        assert has_element?(view, "span", "2008")
        assert has_element?(view, "span", "9.0")

        # Check TV result
        assert has_element?(view, "[data-testid='search-result-card']", "Breaking Bad")
        assert has_element?(view, ".bg-green-100", "TV Show")
        assert has_element?(view, "span", "9.5")
      end
    end

    test "displays results count", %{conn: conn} do
      with_mock Media, [search_content: fn(_query, _opts) -> {:ok, @sample_results} end] do
        {:ok, view, _html} = live(conn, ~p"/search?q=batman")

        assert has_element?(view, "div", "2 results found")
      end
    end
  end

  describe "error handling" do
    test "handles network errors gracefully", %{conn: conn} do
      with_mock Media, [search_content: fn(_query, _opts) ->
        {:error, {:network_error, "Network error occurred. Please check your connection and try again."}}
      end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, ".bg-red-50", "Network error occurred. Please check your connection and try again.")
      end
    end

    test "handles rate limiting errors", %{conn: conn} do
      with_mock Media, [search_content: fn(_query, _opts) ->
        {:error, {:rate_limited, "Too many requests. Please wait a moment and try again."}}
      end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, ".bg-red-50", "Too many requests. Please wait a moment and try again.")
      end
    end
  end
end
