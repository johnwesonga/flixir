defmodule FlixirWeb.SearchLivePerformanceTest do
  @moduledoc """
  Performance tests for the SearchLive module.

  These tests measure search response times, debounce functionality,
  and pagination performance to ensure the search feature meets
  performance requirements.
  """

  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Media.TMDBClient

  @search_timeout 2000  # 2 seconds as per requirements
  @debounce_delay 300   # 300ms debounce delay

  describe "search performance" do
    test "search response time is under 2 seconds", %{conn: conn} do
      # Mock successful API response
      mock_response = %{
        "results" => [
          %{
            "id" => 1,
            "title" => "Test Movie",
            "media_type" => "movie",
            "release_date" => "2023-01-01",
            "overview" => "A test movie",
            "poster_path" => "/test.jpg",
            "genre_ids" => [28, 12],
            "vote_average" => 7.5,
            "popularity" => 100.0
          }
        ],
        "total_pages" => 1,
        "page" => 1
      }

      with_mock TMDBClient, [search_multi: fn(_query, _page) -> {:ok, mock_response} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Measure search response time
        start_time = System.monotonic_time(:millisecond)

        # Trigger debounced search via input change
        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "batman"}})

        # Wait for debounce delay
        Process.sleep(@debounce_delay + 100)

        # Wait for search to complete
        assert render(view) =~ "Test Movie"

        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time

        # Assert response time is under 2 seconds
        assert response_time < @search_timeout,
               "Search took #{response_time}ms, expected under #{@search_timeout}ms"
      end
    end

    test "debounced search reduces API calls", %{conn: conn} do
      # Mock API to track call count
      api_call_count = Agent.start_link(fn -> 0 end)
      {:ok, agent} = api_call_count

      mock_response = %{
        "results" => [],
        "total_pages" => 1,
        "page" => 1
      }

      with_mock TMDBClient, [
        search_multi: fn(_query, _page) ->
          Agent.update(agent, &(&1 + 1))
          {:ok, mock_response}
        end
      ] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Simulate rapid typing (should be debounced)
        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "b"}})

        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "ba"}})

        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "bat"}})

        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "batm"}})

        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "batman"}})

        # Wait for debounce delay plus some buffer
        Process.sleep(@debounce_delay + 100)

        # Should only make one API call due to debouncing
        api_calls = Agent.get(agent, & &1)
        assert api_calls <= 1, "Expected 1 API call due to debouncing, got #{api_calls}"

        Agent.stop(agent)
      end
    end

    test "pagination loads 20 results per page", %{conn: conn} do
      # Create mock response with 20 results
      results = Enum.map(1..20, fn i ->
        %{
          "id" => i,
          "title" => "Movie #{i}",
          "media_type" => "movie",
          "release_date" => "2023-01-01",
          "overview" => "Test movie #{i}",
          "poster_path" => "/test#{i}.jpg",
          "genre_ids" => [28],
          "vote_average" => 7.0,
          "popularity" => 100.0 - i
        }
      end)

      mock_response = %{
        "results" => results,
        "total_pages" => 2,
        "page" => 1
      }

      with_mock TMDBClient, [search_multi: fn(_query, _page) -> {:ok, mock_response} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Trigger debounced search
        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "test"}})

        # Wait for debounce delay
        Process.sleep(@debounce_delay + 100)

        html = render(view)

        # Count the number of result cards
        result_cards = html |> Floki.find("[data-testid='search-result-card']")
        assert length(result_cards) == 20, "Expected 20 results per page, got #{length(result_cards)}"

        # Should show load more button
        assert html =~ "Load More Results"
      end
    end

    test "lazy loading performance for additional pages", %{conn: conn} do
      # Mock first page response
      first_page_results = Enum.map(1..20, fn i ->
        %{
          "id" => i,
          "title" => "Movie #{i}",
          "media_type" => "movie",
          "release_date" => "2023-01-01",
          "overview" => "Test movie #{i}",
          "poster_path" => "/test#{i}.jpg",
          "genre_ids" => [28],
          "vote_average" => 7.0,
          "popularity" => 100.0 - i
        }
      end)

      # Mock second page response
      second_page_results = Enum.map(21..40, fn i ->
        %{
          "id" => i,
          "title" => "Movie #{i}",
          "media_type" => "movie",
          "release_date" => "2023-01-01",
          "overview" => "Test movie #{i}",
          "poster_path" => "/test#{i}.jpg",
          "genre_ids" => [28],
          "vote_average" => 7.0,
          "popularity" => 100.0 - i
        }
      end)

      with_mock TMDBClient, [
        search_multi: fn(_query, page) ->
          case page do
            1 -> {:ok, %{"results" => first_page_results, "total_pages" => 2, "page" => 1}}
            2 -> {:ok, %{"results" => second_page_results, "total_pages" => 2, "page" => 2}}
          end
        end
      ] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Initial search
        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "test"}})

        # Wait for debounce delay
        Process.sleep(@debounce_delay + 100)

        # Measure load more performance
        start_time = System.monotonic_time(:millisecond)

        view
        |> element("[data-testid='load-more-button']")
        |> render_click()

        end_time = System.monotonic_time(:millisecond)
        load_more_time = end_time - start_time

        html = render(view)

        # Should now have 40 results
        result_cards = html |> Floki.find("[data-testid='search-result-card']")
        assert length(result_cards) == 40, "Expected 40 results after load more, got #{length(result_cards)}"

        # Load more should be fast (under 1 second)
        assert load_more_time < 1000,
               "Load more took #{load_more_time}ms, expected under 1000ms"
      end
    end

    test "concurrent search requests are handled gracefully", %{conn: conn} do
      mock_response = %{
        "results" => [
          %{
            "id" => 1,
            "title" => "Test Movie",
            "media_type" => "movie",
            "release_date" => "2023-01-01",
            "overview" => "A test movie",
            "poster_path" => "/test.jpg",
            "genre_ids" => [28],
            "vote_average" => 7.5,
            "popularity" => 100.0
          }
        ],
        "total_pages" => 1,
        "page" => 1
      }

      with_mock TMDBClient, [
        search_multi: fn(_query, _page) ->
          # Simulate some processing time
          Process.sleep(50)
          {:ok, mock_response}
        end
      ] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Start multiple concurrent searches
        tasks = Enum.map(1..5, fn i ->
          Task.async(fn ->
            view
            |> element("#search-form input[name='search[query]']")
            |> render_change(%{search: %{query: "query#{i}"}})
          end)
        end)

        # Wait for all tasks to complete
        Enum.each(tasks, &Task.await/1)

        # Wait for debounce and processing
        Process.sleep(@debounce_delay + 200)

        # Should handle concurrent requests without errors
        html = render(view)
        refute html =~ "error"
        refute html =~ "Error"
      end
    end

    test "image loading optimization with srcset", %{conn: conn} do
      mock_response = %{
        "results" => [
          %{
            "id" => 1,
            "title" => "Test Movie",
            "media_type" => "movie",
            "release_date" => "2023-01-01",
            "overview" => "A test movie",
            "poster_path" => "/test.jpg",
            "genre_ids" => [28],
            "vote_average" => 7.5,
            "popularity" => 100.0
          }
        ],
        "total_pages" => 1,
        "page" => 1
      }

      with_mock TMDBClient, [search_multi: fn(_query, _page) -> {:ok, mock_response} end] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Trigger debounced search
        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "test"}})

        # Wait for debounce delay
        Process.sleep(@debounce_delay + 100)

        html = render(view)

        # Check that images have srcset for responsive loading
        assert html =~ "srcset="
        assert html =~ "w185"  # Small size
        assert html =~ "w300"  # Medium size
        assert html =~ "w500"  # Large size

        # Check that images have sizes attribute
        assert html =~ "sizes="

        # Check lazy loading attributes
        assert html =~ "loading=\"lazy\""
        assert html =~ "decoding=\"async\""
      end
    end
  end

  describe "cache performance" do
    test "cached search results return faster than API calls", %{conn: conn} do
      mock_response = %{
        "results" => [
          %{
            "id" => 1,
            "title" => "Cached Movie",
            "media_type" => "movie",
            "release_date" => "2023-01-01",
            "overview" => "A cached movie",
            "poster_path" => "/cached.jpg",
            "genre_ids" => [28],
            "vote_average" => 8.0,
            "popularity" => 150.0
          }
        ],
        "total_pages" => 1,
        "page" => 1
      }

      with_mock TMDBClient, [
        search_multi: fn(_query, _page) ->
          # Simulate API delay
          Process.sleep(100)
          {:ok, mock_response}
        end
      ] do
        {:ok, view, _html} = live(conn, ~p"/search")

        # First search (should hit API)
        start_time = System.monotonic_time(:millisecond)

        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "cached"}})

        # Wait for debounce delay
        Process.sleep(@debounce_delay + 100)

        first_search_time = System.monotonic_time(:millisecond) - start_time

        # Clear search
        view
        |> element("[data-testid='clear-search-button']")
        |> render_click()

        # Second search with same query (should hit cache)
        start_time = System.monotonic_time(:millisecond)

        view
        |> element("#search-form input[name='search[query]']")
        |> render_change(%{search: %{query: "cached"}})

        # Wait for debounce delay
        Process.sleep(@debounce_delay + 100)

        second_search_time = System.monotonic_time(:millisecond) - start_time

        # Cached search should be significantly faster
        assert second_search_time < first_search_time / 2,
               "Cached search (#{second_search_time}ms) should be faster than API search (#{first_search_time}ms)"
      end
    end
  end
end
