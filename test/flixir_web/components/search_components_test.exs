defmodule FlixirWeb.SearchComponentsTest do
  @moduledoc """
  Tests for search-related UI components.
  """

  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FlixirWeb.SearchComponents

  describe "search_result_card/1" do
    test "renders movie result card with all information" do
      result = %{
        id: 123,
        title: "The Dark Knight",
        media_type: :movie,
        release_date: ~D[2008-07-18],
        overview: "Batman faces the Joker in this epic superhero film.",
        poster_path: "/poster.jpg",
        vote_average: 9.0,
        popularity: 85.5
      }

      html = render_component(&search_result_card/1, result: result)

      assert html =~ "The Dark Knight"
      assert html =~ "2008"
      assert html =~ "Movie"
      assert html =~ "Batman faces the Joker"
      assert html =~ "9.0"
      assert html =~ "Popular"
      assert html =~ "https://image.tmdb.org/t/p/w300/poster.jpg"
      assert html =~ ~s(data-testid="search-result-card")
    end

    test "renders TV show result card" do
      result = %{
        id: 456,
        title: "Breaking Bad",
        media_type: :tv,
        release_date: ~D[2008-01-20],
        overview: "A high school chemistry teacher turned meth cook.",
        poster_path: "/tv_poster.jpg",
        vote_average: 9.5,
        popularity: 92.1
      }

      html = render_component(&search_result_card/1, result: result)

      assert html =~ "Breaking Bad"
      assert html =~ "2008"
      assert html =~ "TV Show"
      assert html =~ "A high school chemistry teacher"
      assert html =~ "9.5"
    end

    test "renders result card with missing poster" do
      result = %{
        id: 789,
        title: "Unknown Movie",
        media_type: :movie,
        release_date: nil,
        overview: nil,
        poster_path: nil,
        vote_average: 0,
        popularity: 0
      }

      html = render_component(&search_result_card/1, result: result)

      assert html =~ "Unknown Movie"
      assert html =~ "Unknown"
      assert html =~ "/images/no-poster.svg"
      refute html =~ "Popular"
      refute html =~ ~s(data-testid="rating-badge")
    end

    test "renders result card with long title and overview" do
      result = %{
        id: 999,
        title: "This is a Very Long Movie Title That Should Be Truncated Properly",
        media_type: :movie,
        release_date: ~D[2023-01-01],
        overview: String.duplicate("This is a very long overview that should be truncated. ", 10),
        poster_path: "/long_poster.jpg",
        vote_average: 7.5,
        popularity: 45.2
      }

      html = render_component(&search_result_card/1, result: result)

      assert html =~ "This is a Very Long Movie Title"
      assert html =~ "line-clamp-2"
      assert html =~ "line-clamp-3"
      assert String.contains?(html, "...")
    end

    test "applies custom CSS classes" do
      result = %{
        id: 111,
        title: "Test Movie",
        media_type: :movie,
        release_date: ~D[2023-01-01],
        overview: "Test overview",
        poster_path: "/test.jpg",
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result, class: "custom-class")

      assert html =~ "custom-class"
    end
  end

  describe "media_type_badge/1" do
    test "renders movie badge" do
      html = render_component(&media_type_badge/1, type: :movie)

      assert html =~ "Movie"
      assert html =~ "bg-blue-100 text-blue-800"
      assert html =~ ~s(data-testid="media-type-badge")
    end

    test "renders TV show badge" do
      html = render_component(&media_type_badge/1, type: :tv)

      assert html =~ "TV Show"
      assert html =~ "bg-green-100 text-green-800"
      assert html =~ ~s(data-testid="media-type-badge")
    end
  end

  describe "rating_badge/1" do
    test "renders rating badge with star icon" do
      html = render_component(&rating_badge/1, rating: 8.7)

      assert html =~ "8.7"
      assert html =~ ~s(data-testid="rating-badge")
      assert html =~ "text-yellow-400"
    end

    test "rounds rating to one decimal place" do
      html = render_component(&rating_badge/1, rating: 7.666)

      assert html =~ "7.7"
    end
  end

  describe "search_results_grid/1" do
    test "renders grid with multiple results" do
      results = [
        %{
          id: 1,
          title: "Movie 1",
          media_type: :movie,
          release_date: ~D[2023-01-01],
          overview: "Overview 1",
          poster_path: "/poster1.jpg",
          vote_average: 8.0,
          popularity: 50.0
        },
        %{
          id: 2,
          title: "TV Show 1",
          media_type: :tv,
          release_date: ~D[2023-02-01],
          overview: "Overview 2",
          poster_path: "/poster2.jpg",
          vote_average: 9.0,
          popularity: 75.0
        }
      ]

      html = render_component(&search_results_grid/1, results: results)

      assert html =~ "Movie 1"
      assert html =~ "TV Show 1"
      assert html =~ ~s(data-testid="search-results-grid")
      refute html =~ ~s(data-testid="skeleton-card")
    end

    test "renders grid with loading skeleton cards" do
      results = [
        %{
          id: 1,
          title: "Movie 1",
          media_type: :movie,
          release_date: ~D[2023-01-01],
          overview: "Overview 1",
          poster_path: "/poster1.jpg",
          vote_average: 8.0,
          popularity: 50.0
        }
      ]

      html = render_component(&search_results_grid/1, results: results, loading: true)

      assert html =~ "Movie 1"
      assert html =~ ~s(data-testid="skeleton-card")
    end

    test "renders empty grid" do
      html = render_component(&search_results_grid/1, results: [])

      assert html =~ ~s(data-testid="search-results-grid")
      refute html =~ ~s(data-testid="search-result-card")
    end

    test "applies custom CSS classes" do
      html = render_component(&search_results_grid/1, results: [], class: "custom-grid-class")

      assert html =~ "custom-grid-class"
    end
  end

  describe "skeleton_card/1" do
    test "renders skeleton loading card" do
      html = render_component(&skeleton_card/1)

      assert html =~ "animate-pulse"
      assert html =~ "bg-gray-300"
      assert html =~ ~s(data-testid="skeleton-card")
    end
  end

  describe "empty_search_state/1" do
    test "renders empty state with query and suggestions" do
      html = render_component(&empty_search_state/1, query: "batman", media_type: :all)

      assert html =~ "No results found"
      assert html =~ "batman"
      assert html =~ "We couldn't find any content"
      assert html =~ "Check your spelling"
      assert html =~ "Try different keywords"
      assert html =~ "Start a new search"
      assert html =~ ~s(data-testid="empty-search-state")
    end

    test "renders empty state for movies filter" do
      html = render_component(&empty_search_state/1, query: "test", media_type: :movie)

      assert html =~ "We couldn't find any movies"
    end

    test "renders empty state for TV shows filter" do
      html = render_component(&empty_search_state/1, query: "test", media_type: :tv)

      assert html =~ "We couldn't find any tv shows"
    end

    test "uses custom clear event" do
      html = render_component(&empty_search_state/1, query: "test", media_type: :all, on_clear: "custom_clear")

      assert html =~ ~s(phx-click="custom_clear")
    end
  end

  describe "initial_search_state/1" do
    test "renders initial welcome state" do
      html = render_component(&initial_search_state/1)

      assert html =~ "Discover Movies & TV Shows"
      assert html =~ "Search through thousands"
      assert html =~ "Popular searches:"
      assert html =~ "Marvel"
      assert html =~ "Breaking Bad"
      assert html =~ "The Office"
      assert html =~ "Star Wars"
      assert html =~ ~s(data-testid="initial-search-state")
    end
  end

  describe "search_loading_state/1" do
    test "renders loading state with spinner" do
      html = render_component(&search_loading_state/1)

      assert html =~ "Searching for great content..."
      assert html =~ "animate-spin"
      assert html =~ ~s(data-testid="search-loading-state")
    end
  end

  describe "helper functions" do
    test "poster_url/1 handles nil poster path" do
      # This tests the private function indirectly through the component
      result = %{
        id: 1,
        title: "Test",
        media_type: :movie,
        release_date: ~D[2023-01-01],
        overview: "Test",
        poster_path: nil,
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result)
      assert html =~ "/images/no-poster.svg"
    end

    test "poster_url/1 handles valid poster path" do
      result = %{
        id: 1,
        title: "Test",
        media_type: :movie,
        release_date: ~D[2023-01-01],
        overview: "Test",
        poster_path: "/valid_poster.jpg",
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result)
      assert html =~ "https://image.tmdb.org/t/p/w300/valid_poster.jpg"
    end

    test "format_release_date/1 handles various date formats" do
      # Test with Date struct
      result_with_date = %{
        id: 1,
        title: "Test",
        media_type: :movie,
        release_date: ~D[2023-05-15],
        overview: "Test",
        poster_path: "/test.jpg",
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result_with_date)
      assert html =~ "2023"

      # Test with nil date
      result_with_nil = %{
        id: 2,
        title: "Test",
        media_type: :movie,
        release_date: nil,
        overview: "Test",
        poster_path: "/test.jpg",
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result_with_nil)
      assert html =~ "Unknown"

      # Test with string date
      result_with_string = %{
        id: 3,
        title: "Test",
        media_type: :movie,
        release_date: "2023-12-25",
        overview: "Test",
        poster_path: "/test.jpg",
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result_with_string)
      assert html =~ "2023"
    end

    test "truncate_text/2 handles text truncation" do
      # Test with long overview
      long_text = String.duplicate("This is a long text. ", 20)

      result = %{
        id: 1,
        title: "Test",
        media_type: :movie,
        release_date: ~D[2023-01-01],
        overview: long_text,
        poster_path: "/test.jpg",
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result)
      assert html =~ "..."

      # Test with short overview
      result_short = %{
        id: 2,
        title: "Test",
        media_type: :movie,
        release_date: ~D[2023-01-01],
        overview: "Short text",
        poster_path: "/test.jpg",
        vote_average: 8.0,
        popularity: 50.0
      }

      html = render_component(&search_result_card/1, result: result_short)
      assert html =~ "Short text"
      refute html =~ "..."
    end
  end
end
