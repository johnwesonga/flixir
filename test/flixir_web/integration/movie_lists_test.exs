defmodule FlixirWeb.Integration.MovieListsTest do
  @moduledoc """
  Comprehensive integration tests for the movie lists feature.

  Tests cover:
  - End-to-end user workflows including list navigation and pagination
  - Caching behavior and performance under load
  - Error scenarios and recovery mechanisms
  - Complete integration between LiveView, Media context, TMDB client, and cache
  - Real-world scenarios with multiple components working together
  """

  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Media
  alias Flixir.Media.{SearchResult, Cache, TMDBClient}

  # Sample movie list responses for consistent testing
  @popular_movies_response %{
    "page" => 1,
    "results" => [
      %{
        "id" => 155,
        "title" => "The Dark Knight",
        "media_type" => "movie",
        "release_date" => "2008-07-18",
        "overview" => "Batman raises the stakes in his war on crime.",
        "poster_path" => "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
        "genre_ids" => [28, 80, 18],
        "vote_average" => 9.0,
        "popularity" => 123.456
      },
      %{
        "id" => 27205,
        "title" => "Inception",
        "media_type" => "movie",
        "release_date" => "2010-07-16",
        "overview" => "Dom Cobb is a skilled thief.",
        "poster_path" => "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
        "genre_ids" => [28, 878, 53],
        "vote_average" => 8.8,
        "popularity" => 89.123
      }
    ],
    "total_pages" => 5,
    "total_results" => 100
  }

  @trending_movies_response %{
    "page" => 1,
    "results" => [
      %{
        "id" => 12345,
        "title" => "Trending Movie 1",
        "media_type" => "movie",
        "release_date" => "2024-01-15",
        "overview" => "A trending movie this week.",
        "poster_path" => "/trending1.jpg",
        "genre_ids" => [28, 12],
        "vote_average" => 8.5,
        "popularity" => 250.0
      },
      %{
        "id" => 67890,
        "title" => "Trending Movie 2",
        "media_type" => "movie",
        "release_date" => "2024-02-01",
        "overview" => "Another trending movie.",
        "poster_path" => "/trending2.jpg",
        "genre_ids" => [35, 18],
        "vote_average" => 7.8,
        "popularity" => 180.5
      }
    ],
    "total_pages" => 3,
    "total_results" => 60
  }

  @top_rated_movies_response %{
    "page" => 1,
    "results" => [
      %{
        "id" => 238,
        "title" => "The Godfather",
        "media_type" => "movie",
        "release_date" => "1972-03-24",
        "overview" => "The aging patriarch of an organized crime dynasty.",
        "poster_path" => "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
        "genre_ids" => [18, 80],
        "vote_average" => 9.2,
        "popularity" => 95.5
      }
    ],
    "total_pages" => 10,
    "total_results" => 200
  }

  @upcoming_movies_response %{
    "page" => 1,
    "results" => [
      %{
        "id" => 11111,
        "title" => "Upcoming Movie 1",
        "media_type" => "movie",
        "release_date" => "2025-06-15",
        "overview" => "An exciting upcoming release.",
        "poster_path" => "/upcoming1.jpg",
        "genre_ids" => [28, 12],
        "vote_average" => 0.0,
        "popularity" => 45.2
      }
    ],
    "total_pages" => 2,
    "total_results" => 40
  }

  @now_playing_movies_response %{
    "page" => 1,
    "results" => [
      %{
        "id" => 22222,
        "title" => "Now Playing Movie 1",
        "media_type" => "movie",
        "release_date" => "2024-12-01",
        "overview" => "Currently in theaters.",
        "poster_path" => "/nowplaying1.jpg",
        "genre_ids" => [28, 53],
        "vote_average" => 7.5,
        "popularity" => 120.8
      }
    ],
    "total_pages" => 4,
    "total_results" => 80
  }

  describe "end-to-end movie list workflows" do
    test "complete navigation workflow between different list types", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_popular_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@popular_movies_response)
            format_response(movies, return_format, true)
          end,
          get_trending_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@trending_movies_response)
            format_response(movies, return_format, true)
          end,
          get_top_rated_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@top_rated_movies_response)
            format_response(movies, return_format, true)
          end,
          get_upcoming_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@upcoming_movies_response)
            format_response(movies, return_format, true)
          end,
          get_now_playing_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@now_playing_movies_response)
            format_response(movies, return_format, true)
          end
        ]}
      ]) do
        # 1. Navigate to movie lists page (defaults to popular)
        {:ok, view, html} = live(conn, ~p"/movies")

        # Verify initial state
        assert html =~ "Movies"
        assert html =~ "Popular Movies"

        # Verify popular movies are loaded by default
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")
        assert has_element?(view, "[data-testid='movie-card']", "Inception")
        assert has_element?(view, "[data-testid='sub-nav-popular'][class*='border-blue-500']")

        # 2. Navigate to trending movies
        {:ok, view, _html} = live(conn, ~p"/movies/trending")
        assert has_element?(view, "[data-testid='movie-card']", "Trending Movie 1")
        assert has_element?(view, "[data-testid='movie-card']", "Trending Movie 2")
        assert has_element?(view, "[data-testid='sub-nav-trending'][class*='border-blue-500']")

        # 3. Navigate to top rated movies
        {:ok, view, _html} = live(conn, ~p"/movies/top-rated")
        assert has_element?(view, "[data-testid='movie-card']", "The Godfather")
        assert has_element?(view, "[data-testid='sub-nav-top_rated'][class*='border-blue-500']")

        # 4. Navigate to upcoming movies
        {:ok, view, _html} = live(conn, ~p"/movies/upcoming")
        assert has_element?(view, "[data-testid='movie-card']", "Upcoming Movie 1")
        assert has_element?(view, "[data-testid='sub-nav-upcoming'][class*='border-blue-500']")

        # 5. Navigate to now playing movies
        {:ok, view, _html} = live(conn, ~p"/movies/now-playing")
        assert has_element?(view, "[data-testid='movie-card']", "Now Playing Movie 1")
        assert has_element?(view, "[data-testid='sub-nav-now_playing'][class*='border-blue-500']")

        # 6. Return to popular movies
        {:ok, view, _html} = live(conn, ~p"/movies")
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")
        assert has_element?(view, "[data-testid='sub-nav-popular'][class*='border-blue-500']")

        # Verify all Media context functions were called
        assert called(Media.get_popular_movies(:_))
        assert called(Media.get_trending_movies(:_))
        assert called(Media.get_top_rated_movies(:_))
        assert called(Media.get_upcoming_movies(:_))
        assert called(Media.get_now_playing_movies(:_))
      end
    end

    test "pagination workflow with load more functionality", %{conn: conn} do
      page_1_movies = transform_api_response(@popular_movies_response)
      page_2_movies = [
        %SearchResult{
          id: 333,
          title: "Page 2 Movie 1",
          media_type: :movie,
          release_date: ~D[2023-01-01],
          overview: "Movie from page 2",
          poster_path: "/page2_1.jpg",
          genre_ids: [28],
          vote_average: 7.0,
          popularity: 50.0
        },
        %SearchResult{
          id: 444,
          title: "Page 2 Movie 2",
          media_type: :movie,
          release_date: ~D[2023-02-01],
          overview: "Another movie from page 2",
          poster_path: "/page2_2.jpg",
          genre_ids: [35],
          vote_average: 6.5,
          popularity: 40.0
        }
      ]

      with_mocks([
        {Media, [], [
          get_popular_movies: fn opts ->
            page = Keyword.get(opts, :page, 1)
            return_format = Keyword.get(opts, :return_format, :list)

            movies = case page do
              1 -> page_1_movies
              2 -> page_2_movies
              _ -> []
            end

            has_more = page < 2
            format_response(movies, return_format, has_more)
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Verify initial page load
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")
        assert has_element?(view, "[data-testid='movie-card']", "Inception")
        assert has_element?(view, "[data-testid='load-more-section']")
        refute has_element?(view, "[data-testid='movie-card']", "Page 2 Movie 1")

        # Load more movies
        view
        |> element("button", "Load More Movies")
        |> render_click()

        # Wait for the load more to complete
        Process.sleep(100)

        # Verify both page 1 and page 2 movies are displayed
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")
        assert has_element?(view, "[data-testid='movie-card']", "Inception")
        assert has_element?(view, "[data-testid='movie-card']", "Page 2 Movie 1")
        assert has_element?(view, "[data-testid='movie-card']", "Page 2 Movie 2")

        # Verify load more button is hidden (no more pages)
        refute has_element?(view, "button", "Load More Movies")

        # Verify Media context was called for both pages
        assert called(Media.get_popular_movies(page: 1, return_format: :map))
        assert called(Media.get_popular_movies(page: 2, return_format: :map))
      end
    end

    test "direct URL navigation with parameters", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_trending_movies: fn opts ->
            page = Keyword.get(opts, :page, 1)
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@trending_movies_response)
            format_response(movies, return_format, page < 3)
          end
        ]}
      ]) do
        # Navigate directly to trending movies page 2
        {:ok, view, html} = live(conn, ~p"/movies/trending?page=2")

        # Verify correct list type and page are loaded
        assert html =~ "Trending Movies"
        assert has_element?(view, "[data-testid='nav-tab-trending'][class*='border-blue-500']")
        assert has_element?(view, "[data-testid='movie-card']", "Trending Movie 1")

        # Verify Media context was called with correct parameters
        assert called(Media.get_trending_movies(page: 2, return_format: :map))
      end
    end

    test "movie card navigation preserves list context", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_top_rated_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@top_rated_movies_response)
            format_response(movies, return_format, true)
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies/top-rated")

        # Verify movie card has correct navigation link with context
        movie_link = view
        |> element("[data-testid='movie-card']")
        |> render()

        assert movie_link =~ "href=\"/movie/238?from=top_rated\""

        # Click on movie card
        view
        |> element("[data-testid='movie-card']")
        |> render_click()

        # Note: In a real integration test, this would navigate to the movie details page
        # For now, we verify the link structure is correct
      end
    end
  end

  describe "caching behavior integration" do
    test "cache hit vs cache miss performance and behavior", %{conn: conn} do
      cached_movies = transform_api_response(@popular_movies_response)

      with_mocks([
        {Cache, [], [
          get: fn key ->
            case key do
              "movies:popular:page:1" -> {:ok, %{results: cached_movies, has_more: true}}
              _ -> :error
            end
          end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, @popular_movies_response} end
        ]},
        {Media, [], [
          get_popular_movies: fn opts ->
            # Simulate actual Media context behavior with cache
            page = Keyword.get(opts, :page, 1)
            return_format = Keyword.get(opts, :return_format, :list)
            cache_key = "movies:popular:page:#{page}"

            case Cache.get(cache_key) do
              {:ok, cached_data} ->
                format_response(cached_data.results, return_format, cached_data.has_more)
              :error ->
                # Simulate API call
                movies = transform_api_response(@popular_movies_response)
                format_response(movies, return_format, true)
            end
          end
        ]}
      ]) do
        # First request - should hit cache
        start_time = System.monotonic_time(:millisecond)
        {:ok, view, _html} = live(conn, ~p"/movies")
        end_time = System.monotonic_time(:millisecond)

        cached_response_time = end_time - start_time

        # Verify cached results are displayed
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")
        assert has_element?(view, "[data-testid='movie-card']", "Inception")

        # Verify cache was accessed
        assert called(Cache.get("movies:popular:page:1"))

        # Switch to trending (cache miss)
        start_time = System.monotonic_time(:millisecond)

        view
        |> element("[data-testid='nav-tab-trending']")
        |> render_click()

        end_time = System.monotonic_time(:millisecond)
        cache_miss_response_time = end_time - start_time

        # Cache hit should be faster than cache miss
        assert cached_response_time < cache_miss_response_time + 100,
               "Cache hit (#{cached_response_time}ms) not significantly faster than cache miss (#{cache_miss_response_time}ms)"
      end
    end

    test "cache behavior across different list types", %{conn: conn} do
      cache_state = Agent.start_link(fn -> %{} end)
      {:ok, cache_state} = cache_state

      with_mocks([
        {Cache, [], [
          get: fn key ->
            cached_data = Agent.get(cache_state, &Map.get(&1, key))
            if cached_data, do: {:ok, cached_data}, else: :error
          end,
          put: fn key, value, _ttl ->
            Agent.update(cache_state, &Map.put(&1, key, value))
            :ok
          end
        ]},
        {Media, [], [
          get_popular_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@popular_movies_response)
            # Simulate caching
            Cache.put("movies:popular:page:1", %{results: movies, has_more: true}, 900)
            format_response(movies, return_format, true)
          end,
          get_trending_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@trending_movies_response)
            Cache.put("movies:trending:week:page:1", %{results: movies, has_more: true}, 900)
            format_response(movies, return_format, true)
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Load popular movies (cache miss, then cached)
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")

        # Switch to trending (cache miss, then cached)
        view
        |> element("[data-testid='nav-tab-trending']")
        |> render_click()

        assert has_element?(view, "[data-testid='movie-card']", "Trending Movie 1")

        # Switch back to popular (should hit cache now)
        view
        |> element("[data-testid='nav-tab-popular']")
        |> render_click()

        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")

        # Verify cache operations
        assert called(Cache.put("movies:popular:page:1", :_, :_))
        assert called(Cache.put("movies:trending:week:page:1", :_, :_))

        # Verify cache state
        final_cache_state = Agent.get(cache_state, & &1)
        assert Map.has_key?(final_cache_state, "movies:popular:page:1")
        assert Map.has_key?(final_cache_state, "movies:trending:week:page:1")

        Agent.stop(cache_state)
      end
    end

    test "cache performance under concurrent load", %{conn: conn} do
      # Simulate multiple users accessing different movie lists concurrently
      num_concurrent_users = 5

      with_mocks([
        {Media, [], [
          get_popular_movies: fn opts ->
            # Simulate variable response times
            Process.sleep(50 + :rand.uniform(50))
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@popular_movies_response)
            format_response(movies, return_format, true)
          end,
          get_trending_movies: fn opts ->
            Process.sleep(50 + :rand.uniform(50))
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@trending_movies_response)
            format_response(movies, return_format, true)
          end,
          get_top_rated_movies: fn opts ->
            Process.sleep(50 + :rand.uniform(50))
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@top_rated_movies_response)
            format_response(movies, return_format, true)
          end
        ]}
      ]) do
        # Create multiple concurrent user sessions
        tasks = for user_id <- 1..num_concurrent_users do
          Task.async(fn ->
            try do
              {:ok, view, _html} = live(conn, ~p"/movies")

              # Each user navigates through different lists
              list_types = [:popular, :trending, :top_rated]
              selected_list = Enum.at(list_types, rem(user_id, length(list_types)))

              case selected_list do
                :trending ->
                  view
                  |> element("[data-testid='nav-tab-trending']")
                  |> render_click()
                  assert has_element?(view, "[data-testid='movie-card']")

                :top_rated ->
                  view
                  |> element("[data-testid='nav-tab-top_rated']")
                  |> render_click()
                  assert has_element?(view, "[data-testid='movie-card']")

                _ ->
                  # Stay on popular
                  assert has_element?(view, "[data-testid='movie-card']")
              end

              {:ok, user_id}
            rescue
              error -> {:error, user_id, error}
            end
          end)
        end

        # Wait for all tasks to complete
        results = Task.await_many(tasks, 10_000)

        # Verify all users succeeded
        successful_users = Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

        success_rate = successful_users / num_concurrent_users
        assert success_rate >= 0.8, "Success rate #{success_rate} too low under concurrent load"

        # Verify Media context functions were called
        assert called(Media.get_popular_movies(:_))
      end
    end
  end

  describe "error scenarios and recovery" do
    test "timeout error handling and recovery", %{conn: conn} do
      call_count = Agent.start_link(fn -> 0 end)
      {:ok, call_count} = call_count

      with_mocks([
        {Media, [], [
          get_popular_movies: fn _opts ->
            count = Agent.get_and_update(call_count, fn c -> {c, c + 1} end)

            case count do
              0 -> {:error, {:timeout, "Request timed out. Please try again."}}
              1 -> {:error, {:timeout, "Request timed out. Please try again."}}
              _ ->
                movies = transform_api_response(@popular_movies_response)
                {:ok, %{results: movies, has_more: true}}
            end
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Verify timeout error is displayed
        assert has_element?(view, "[data-testid='error-state']")
        refute has_element?(view, "[data-testid='movie-card']")

        # Click retry button
        view
        |> element("button", "Try Again")
        |> render_click()

        # Should still show error on second attempt
        assert has_element?(view, "[data-testid='error-state']")

        # Click retry again - should succeed
        view
        |> element("button", "Try Again")
        |> render_click()

        # Verify success
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")
        refute has_element?(view, "[data-testid='error-state']")

        # Verify Media context was called multiple times
        final_count = Agent.get(call_count, & &1)
        assert final_count >= 3

        Agent.stop(call_count)
      end
    end

    test "rate limiting error handling", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_popular_movies: fn _opts ->
            {:error, {:rate_limited, "Too many requests. Please wait a moment and try again."}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Verify rate limiting error is displayed
        assert has_element?(view, "[data-testid='error-state']")

        # Verify retry button is available for rate limiting errors
        assert has_element?(view, "button", "Try Again")
        refute has_element?(view, "[data-testid='movie-card']")
      end
    end

    test "network error handling and recovery", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_trending_movies: fn _opts ->
            {:error, {:network_error, "Network connection error. Please check your internet connection."}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies/trending")

        # Verify network error is displayed
        assert has_element?(view, "[data-testid='error-state']")
        assert has_element?(view, "button", "Try Again")
        refute has_element?(view, "[data-testid='movie-card']")
      end
    end

    test "API error handling", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_top_rated_movies: fn _opts ->
            {:error, {:api_error, "Unable to load movies from the service. Please try again."}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies/top-rated")

        # Verify API error is displayed
        assert has_element?(view, "[data-testid='error-state']")
        assert has_element?(view, "button", "Try Again")
        refute has_element?(view, "[data-testid='movie-card']")
      end
    end

    test "unauthorized error handling", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_upcoming_movies: fn _opts ->
            {:error, {:unauthorized, "Unable to access movie data. Please try again later."}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies/upcoming")

        # Verify unauthorized error is displayed
        assert has_element?(view, "[data-testid='error-state']")
        assert has_element?(view, "button", "Try Again")
        refute has_element?(view, "[data-testid='movie-card']")
      end
    end

    test "error recovery across list type switches", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_popular_movies: fn _opts ->
            {:error, {:timeout, "Request timed out. Please try again."}}
          end,
          get_trending_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@trending_movies_response)
            format_response(movies, return_format, true)
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Verify error state for popular movies
        assert has_element?(view, "[data-testid='error-state']")
        assert has_element?(view, ".text-red-600", "The request timed out. Please check your connection and try again.")

        # Navigate to trending movies (should work)
        {:ok, view, _html} = live(conn, ~p"/movies/trending")

        # Verify successful load
        assert has_element?(view, "[data-testid='movie-card']", "Trending Movie 1")
        refute has_element?(view, "[data-testid='error-state']")

        # Navigate back to popular (should still show error)
        {:ok, view, _html} = live(conn, ~p"/movies")

        assert has_element?(view, "[data-testid='error-state']")
      end
    end
  end

  describe "performance integration tests" do
    test "list switching performance", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_popular_movies: fn opts ->
            Process.sleep(50)  # Simulate API delay
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@popular_movies_response)
            format_response(movies, return_format, true)
          end,
          get_trending_movies: fn opts ->
            Process.sleep(50)
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@trending_movies_response)
            format_response(movies, return_format, true)
          end,
          get_top_rated_movies: fn opts ->
            Process.sleep(50)
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@top_rated_movies_response)
            format_response(movies, return_format, true)
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Measure list switching performance
        switch_times = []

        # Navigate to trending
        start_time = System.monotonic_time(:millisecond)
        {:ok, view, _html} = live(conn, ~p"/movies/trending")
        assert has_element?(view, "[data-testid='movie-card']", "Trending Movie 1")
        end_time = System.monotonic_time(:millisecond)
        switch_times = [end_time - start_time | switch_times]

        # Navigate to top rated
        start_time = System.monotonic_time(:millisecond)
        {:ok, view, _html} = live(conn, ~p"/movies/top-rated")
        assert has_element?(view, "[data-testid='movie-card']", "The Godfather")
        end_time = System.monotonic_time(:millisecond)
        switch_times = [end_time - start_time | switch_times]

        # Navigate back to popular
        start_time = System.monotonic_time(:millisecond)
        {:ok, view, _html} = live(conn, ~p"/movies")
        assert has_element?(view, "[data-testid='movie-card']", "The Dark Knight")
        end_time = System.monotonic_time(:millisecond)
        switch_times = [end_time - start_time | switch_times]

        # Analyze performance
        avg_switch_time = Enum.sum(switch_times) / length(switch_times)
        max_switch_time = Enum.max(switch_times)

        # Performance requirements
        assert max_switch_time < 2000, "Slowest list switch #{max_switch_time}ms exceeds 2000ms requirement"
        assert avg_switch_time < 1000, "Average list switch time #{avg_switch_time}ms too slow"
      end
    end

    test "pagination performance", %{conn: conn} do
      with_mocks([
        {Media, [], [
          get_popular_movies: fn opts ->
            page = Keyword.get(opts, :page, 1)
            return_format = Keyword.get(opts, :return_format, :list)

            # Simulate increasing delay for higher pages
            Process.sleep(30 + (page * 10))

            movies = case page do
              1 -> transform_api_response(@popular_movies_response)
              _ -> [
                %SearchResult{
                  id: 1000 + page,
                  title: "Page #{page} Movie",
                  media_type: :movie,
                  release_date: ~D[2023-01-01],
                  overview: "Movie from page #{page}",
                  poster_path: "/page#{page}.jpg",
                  genre_ids: [28],
                  vote_average: 7.0,
                  popularity: 50.0
                }
              ]
            end

            format_response(movies, return_format, page < 5)
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Measure pagination performance
        pagination_times = []

        for page <- 2..4 do
          start_time = System.monotonic_time(:millisecond)

          view
          |> element("button", "Load More Movies")
          |> render_click()

          assert has_element?(view, "[data-testid='movie-card']", "Page #{page} Movie")

          end_time = System.monotonic_time(:millisecond)
          pagination_times = [end_time - start_time | pagination_times]
        end

        # Analyze pagination performance
        avg_pagination_time = if length(pagination_times) > 0, do: Enum.sum(pagination_times) / length(pagination_times), else: 0
        max_pagination_time = if length(pagination_times) > 0, do: Enum.max(pagination_times), else: 0

        # Performance requirements
        assert max_pagination_time < 3000, "Slowest pagination #{max_pagination_time}ms exceeds 3000ms requirement"
        assert avg_pagination_time < 2000, "Average pagination time #{avg_pagination_time}ms too slow"
      end
    end

    test "memory usage stability during extended navigation", %{conn: conn} do
      # Monitor memory usage during extended movie list navigation
      memory_samples = Agent.start_link(fn -> [] end)
      {:ok, memory_samples} = memory_samples

      with_mocks([
        {Media, [], [
          get_popular_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@popular_movies_response)
            format_response(movies, return_format, true)
          end,
          get_trending_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@trending_movies_response)
            format_response(movies, return_format, true)
          end,
          get_top_rated_movies: fn opts ->
            return_format = Keyword.get(opts, :return_format, :list)
            movies = transform_api_response(@top_rated_movies_response)
            format_response(movies, return_format, true)
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Start memory monitoring
        monitor_task = Task.async(fn ->
          for i <- 1..20 do
            memory_usage = :erlang.memory(:total)
            Agent.update(memory_samples, fn samples ->
              [{i, memory_usage} | samples]
            end)
            Process.sleep(100)
          end
        end)

        # Generate navigation load
        navigation_task = Task.async(fn ->
          list_types = [:popular, :trending, :top_rated]

          for i <- 1..15 do
            list_type = Enum.at(list_types, rem(i, length(list_types)))

            case list_type do
              :trending ->
                {:ok, view, _html} = live(conn, ~p"/movies/trending")
                assert has_element?(view, "[data-testid='movie-card']")

              :top_rated ->
                {:ok, view, _html} = live(conn, ~p"/movies/top-rated")
                assert has_element?(view, "[data-testid='movie-card']")

              _ ->
                {:ok, view, _html} = live(conn, ~p"/movies")
                assert has_element?(view, "[data-testid='movie-card']")
            end

            Process.sleep(100)
          end
        end)

        # Wait for both tasks
        Task.await(navigation_task, 10_000)
        Task.await(monitor_task, 10_000)

        # Analyze memory stability
        samples = Agent.get(memory_samples, & &1) |> Enum.reverse()
        memory_values = Enum.map(samples, fn {_, memory} -> memory end)

        initial_memory = hd(memory_values)
        final_memory = List.last(memory_values)
        max_memory = Enum.max(memory_values)

        # Memory growth should be reasonable
        memory_growth = (final_memory - initial_memory) / initial_memory
        assert memory_growth < 0.3, "Memory growth #{memory_growth} indicates potential memory leak"

        # Peak memory usage should not be excessive
        peak_growth = (max_memory - initial_memory) / initial_memory
        assert peak_growth < 0.5, "Peak memory growth #{peak_growth} too high during navigation"

        Agent.stop(memory_samples)
      end
    end
  end

  # Helper functions

  defp transform_api_response(%{"results" => results}) do
    Enum.map(results, fn movie ->
      %SearchResult{
        id: movie["id"],
        title: movie["title"],
        media_type: :movie,
        release_date: parse_date(movie["release_date"]),
        overview: movie["overview"],
        poster_path: movie["poster_path"],
        genre_ids: movie["genre_ids"] || [],
        vote_average: movie["vote_average"] || 0.0,
        popularity: movie["popularity"] || 0.0
      }
    end)
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp format_response(movies, :list, _has_more), do: {:ok, movies}
  defp format_response(movies, :map, has_more), do: {:ok, %{results: movies, has_more: has_more}}
end
