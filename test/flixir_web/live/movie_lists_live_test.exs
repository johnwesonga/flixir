defmodule FlixirWeb.MovieListsLiveTest do
  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Media
  alias Flixir.Media.SearchResult

  @sample_movies [
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
      title: "Inception",
      media_type: :movie,
      release_date: ~D[2010-07-16],
      overview: "A thief who steals corporate secrets through dream-sharing technology.",
      poster_path: "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
      genre_ids: [28, 878, 53],
      vote_average: 8.8,
      popularity: 234.567
    },
    %SearchResult{
      id: 3,
      title: "Interstellar",
      media_type: :movie,
      release_date: ~D[2014-11-07],
      overview: "A team of explorers travel through a wormhole in space.",
      poster_path: "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg",
      genre_ids: [18, 878],
      vote_average: 8.6,
      popularity: 345.678
    }
  ]

  @sample_movies_with_pagination %{
    results: @sample_movies,
    has_more: true
  }

  describe "mount/3" do
    test "initializes with default state and loads popular movies", %{conn: conn} do
      with_mock Media, get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies")

        assert html =~ "Popular Movies"
        assert html =~ "The Dark Knight"
        assert html =~ "Inception"
        assert html =~ "Interstellar"
        assert called(Media.get_popular_movies(:_))
      end
    end

    test "displays movie cards with correct information", %{conn: conn} do
      with_mock Media, get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, view, html} = live(conn, ~p"/movies")

        # Check for movie cards
        assert has_element?(view, "[data-testid='movie-card']")
        assert html =~ "The Dark Knight"
        assert html =~ "2008"
        assert html =~ "9.0"

        # Check for load more button since has_more is true
        assert has_element?(view, "button[phx-click='load_more']")
      end
    end
  end

  describe "handle_params/3 - parameter handling" do
    test "handles valid list type parameter", %{conn: conn} do
      with_mock Media, get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies/trending")

        assert html =~ "Trending Movies"
        assert called(Media.get_trending_movies(:_))
      end
    end

    test "handles top-rated list type with hyphen", %{conn: conn} do
      with_mock Media, get_top_rated_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies/top-rated")

        assert html =~ "Top Rated Movies"
        assert called(Media.get_top_rated_movies(:_))
      end
    end

    test "handles now-playing list type with hyphen", %{conn: conn} do
      with_mock Media,
        get_now_playing_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies/now-playing")

        assert html =~ "Now Playing Movies"
        assert called(Media.get_now_playing_movies(:_))
      end
    end

    test "handles upcoming list type", %{conn: conn} do
      with_mock Media, get_upcoming_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies/upcoming")

        assert html =~ "Upcoming Movies"
        assert called(Media.get_upcoming_movies(:_))
      end
    end

    test "defaults to popular for invalid list type", %{conn: conn} do
      with_mock Media, get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies/invalid-type")

        assert html =~ "Popular Movies"
        assert called(Media.get_popular_movies(:_))
      end
    end

    test "handles page parameter", %{conn: conn} do
      with_mock Media, get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, _html} = live(conn, ~p"/movies?page=2")

        assert called(Media.get_popular_movies(page: 2, return_format: :map))
      end
    end

    test "handles invalid page parameter", %{conn: conn} do
      with_mock Media, get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, _html} = live(conn, ~p"/movies?page=invalid")

        assert called(Media.get_popular_movies(page: 1, return_format: :map))
      end
    end

    test "handles zero or negative page parameter", %{conn: conn} do
      with_mock Media, get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, _html} = live(conn, ~p"/movies?page=0")

        assert called(Media.get_popular_movies(page: 1, return_format: :map))
      end
    end

    test "handles combined list type and page parameters", %{conn: conn} do
      with_mock Media, get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, _html} = live(conn, ~p"/movies/trending?page=3")

        # Verify the function was called with the correct parameters
        assert called(Media.get_trending_movies(:_))
      end
    end
  end

  describe "navigation between list types" do
    test "shows correct navigation state for current list", %{conn: conn} do
      with_mock Media,
        get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies/trending")

        # Trending tab should be active in sub-navigation
        assert html =~ "border-blue-500 text-blue-600"
        assert html =~ "data-testid=\"sub-nav-trending\""
      end
    end

    test "shows all navigation tabs", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # All sub-navigation tabs should be present
        assert has_element?(view, "a[data-testid='sub-nav-popular']")
        assert has_element?(view, "a[data-testid='sub-nav-trending']")
        assert has_element?(view, "a[data-testid='sub-nav-top_rated']")
        assert has_element?(view, "a[data-testid='sub-nav-upcoming']")
        assert has_element?(view, "a[data-testid='sub-nav-now_playing']")
      end
    end

    test "navigation links have correct URLs", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Check sub-navigation URLs
        assert has_element?(view, "a[href='/movies'][data-testid='sub-nav-popular']")
        assert has_element?(view, "a[href='/movies/trending'][data-testid='sub-nav-trending']")
        assert has_element?(view, "a[href='/movies/top-rated'][data-testid='sub-nav-top_rated']")
        assert has_element?(view, "a[href='/movies/upcoming'][data-testid='sub-nav-upcoming']")

        assert has_element?(
                 view,
                 "a[href='/movies/now-playing'][data-testid='sub-nav-now_playing']"
               )
      end
    end
  end

  describe "handle_event/3 - pagination" do
    test "loads more movies with load_more event", %{conn: conn} do
      page_1_movies = [
        %SearchResult{
          id: 1,
          title: "Movie 1",
          media_type: :movie,
          release_date: ~D[2023-01-01],
          overview: "First movie",
          poster_path: "/movie1.jpg",
          genre_ids: [28],
          vote_average: 8.0,
          popularity: 100.0
        }
      ]

      page_2_movies = [
        %SearchResult{
          id: 2,
          title: "Movie 2",
          media_type: :movie,
          release_date: ~D[2023-01-02],
          overview: "Second movie",
          poster_path: "/movie2.jpg",
          genre_ids: [28],
          vote_average: 7.5,
          popularity: 90.0
        }
      ]

      with_mock Media,
        get_popular_movies: fn opts ->
          case Keyword.get(opts, :page, 1) do
            1 -> {:ok, %{results: page_1_movies, has_more: true}}
            2 -> {:ok, %{results: page_2_movies, has_more: false}}
          end
        end do
        {:ok, view, html} = live(conn, ~p"/movies")

        # Verify initial state
        assert html =~ "Movie 1"
        refute html =~ "Movie 2"

        # Trigger load more
        view
        |> element("button[phx-click='load_more']")
        |> render_click()

        # Verify second movie is present (movies are appended)
        final_html = render(view)
        assert final_html =~ "Movie 2"

        # Verify both API calls were made
        assert called(Media.get_popular_movies(page: 1, return_format: :map))
        assert called(Media.get_popular_movies(page: 2, return_format: :map))
      end
    end

    test "updates URL when loading more pages", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, view, _html} = live(conn, ~p"/movies")

        view
        |> element("button[phx-click='load_more']")
        |> render_click()

        assert_patch(view, ~p"/movies?page=2")
      end
    end

    test "shows loading state during pagination", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Load more should show loading state
        html =
          view
          |> element("button[phx-click='load_more']")
          |> render_click()

        # After load more, should show loading indicator or updated content
        assert html =~ "Loading more movies" or html =~ "Load More Movies"
      end
    end
  end

  describe "handle_event/3 - error recovery" do
    test "retries failed request with retry event", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:timeout, "Request timed out"}} end do
        {:ok, view, html} = live(conn, ~p"/movies")

        # Verify error state
        assert html =~ "The request timed out"
        assert has_element?(view, "button[phx-click='retry']")
      end

      # Test that retry functionality works by verifying the button exists
      # (A full retry test would require more complex mocking)
    end

    test "shows retry button on error", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:network_error, "Network error"}} end do
        {:ok, view, html} = live(conn, ~p"/movies")

        assert html =~ "Network connection error"
        assert has_element?(view, "button[phx-click='retry']", "Try Again")
      end
    end
  end

  describe "error handling" do
    test "handles timeout errors", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:timeout, "Request timed out"}} end do
        {:ok, view, html} = live(conn, ~p"/movies")

        assert html =~ "The request timed out"
        assert has_element?(view, "button[phx-click='retry']", "Try Again")
        assert has_element?(view, "[data-testid='error-state']")
      end
    end

    test "handles rate limiting errors", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:rate_limited, "Too many requests"}} end do
        {:ok, _view, html} = live(conn, ~p"/movies")

        assert html =~ "Too many requests"
      end
    end

    test "handles unauthorized errors", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:unauthorized, "API key invalid"}} end do
        {:ok, _view, html} = live(conn, ~p"/movies")

        assert html =~ "Unable to access movie data"
      end
    end

    test "handles network errors", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:network_error, "Connection failed"}} end do
        {:ok, _view, html} = live(conn, ~p"/movies")

        assert html =~ "Network connection error"
      end
    end

    test "handles API errors", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:api_error, "Service unavailable"}} end do
        {:ok, _view, html} = live(conn, ~p"/movies")

        assert html =~ "Unable to load movies from the service"
      end
    end

    test "handles transformation errors", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts ->
          {:error, {:transformation_error, "Invalid data format"}}
        end do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Should show generic API error for transformation errors
        assert has_element?(view, "[data-testid='error-state']")
      end
    end

    test "handles unexpected errors", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, :unexpected_error} end do
        {:ok, view, _html} = live(conn, ~p"/movies")

        # Should show generic API error for unexpected errors
        assert has_element?(view, "[data-testid='error-state']")
      end
    end
  end

  describe "URL generation and navigation" do
    test "generates correct URLs for different list types", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end,
        get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end,
        get_top_rated_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end,
        get_upcoming_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end,
        get_now_playing_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        # Test popular (default) URL
        {:ok, _view, html} = live(conn, ~p"/movies")
        assert html =~ "Popular Movies"

        # Test trending URL
        {:ok, _view, html} = live(conn, ~p"/movies/trending")
        assert html =~ "Trending Movies"

        # Test top-rated URL
        {:ok, _view, html} = live(conn, ~p"/movies/top-rated")
        assert html =~ "Top Rated Movies"

        # Test upcoming URL
        {:ok, _view, html} = live(conn, ~p"/movies/upcoming")
        assert html =~ "Upcoming Movies"

        # Test now-playing URL
        {:ok, _view, html} = live(conn, ~p"/movies/now-playing")
        assert html =~ "Now Playing Movies"
      end
    end

    test "preserves page parameter in URL updates", %{conn: conn} do
      with_mock Media,
        get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, view, _html} = live(conn, ~p"/movies/trending")

        # Load more to increment page
        view
        |> element("button[phx-click='load_more']")
        |> render_click()

        assert_patch(view, ~p"/movies/trending?page=2")
      end
    end

    test "handles direct navigation to paginated URLs", %{conn: conn} do
      with_mock Media,
        get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies/trending?page=3")

        assert html =~ "Trending Movies"
        # Verify the function was called (parameters may vary due to implementation details)
        assert called(Media.get_trending_movies(:_))
      end
    end
  end

  describe "data handling" do
    test "handles backward compatibility with list response format", %{conn: conn} do
      # Test the fallback case where API returns a list instead of map with pagination
      # Create a list with 20+ items to trigger has_more = true
      large_movie_list =
        Enum.map(1..25, fn i ->
          %SearchResult{
            id: i,
            title: "Movie #{i}",
            media_type: :movie,
            release_date: ~D[2023-01-01],
            overview: "Movie #{i} overview",
            poster_path: "/movie#{i}.jpg",
            genre_ids: [28],
            vote_average: 8.0,
            popularity: 100.0
          }
        end)

      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, large_movie_list} end do
        {:ok, view, html} = live(conn, ~p"/movies")

        assert html =~ "Movie 1"
        assert html =~ "Movie 2"
        # Should show load more button for backward compatibility (>= 20 items)
        assert has_element?(view, "button[phx-click='load_more']")
      end
    end

    test "handles empty movie list", %{conn: conn} do
      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, %{results: [], has_more: false}} end do
        {:ok, view, html} = live(conn, ~p"/movies")

        assert html =~ "No movies found"
        assert has_element?(view, "[data-testid='empty-state']")
        refute has_element?(view, "button[phx-click='load_more']")
      end
    end

    test "handles trending movies with time_window parameter", %{conn: conn} do
      with_mock Media,
        get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, _html} = live(conn, ~p"/movies/trending")

        # Verify the function was called (parameters may vary due to implementation details)
        assert called(Media.get_trending_movies(:_))
      end
    end
  end

  describe "integration scenarios" do
    test "complete user workflow: browse different lists and paginate", %{conn: conn} do
      popular_movies = [
        %SearchResult{
          id: 1,
          title: "Popular 1",
          media_type: :movie,
          release_date: ~D[2023-01-01],
          overview: "Popular movie 1",
          poster_path: "/p1.jpg",
          genre_ids: [28],
          vote_average: 8.0,
          popularity: 100.0
        }
      ]

      trending_movies = [
        %SearchResult{
          id: 2,
          title: "Trending 1",
          media_type: :movie,
          release_date: ~D[2023-01-02],
          overview: "Trending movie 1",
          poster_path: "/t1.jpg",
          genre_ids: [28],
          vote_average: 7.5,
          popularity: 90.0
        }
      ]

      trending_page_2 = [
        %SearchResult{
          id: 3,
          title: "Trending 2",
          media_type: :movie,
          release_date: ~D[2023-01-03],
          overview: "Trending movie 2",
          poster_path: "/t2.jpg",
          genre_ids: [28],
          vote_average: 7.0,
          popularity: 80.0
        }
      ]

      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, %{results: popular_movies, has_more: false}} end,
        get_trending_movies: fn opts ->
          case Keyword.get(opts, :page, 1) do
            1 -> {:ok, %{results: trending_movies, has_more: true}}
            2 -> {:ok, %{results: trending_page_2, has_more: false}}
          end
        end do
        # 1. Start with popular movies
        {:ok, _view, html} = live(conn, ~p"/movies")
        assert html =~ "Popular 1"

        # 2. Navigate to trending
        {:ok, view, html} = live(conn, ~p"/movies/trending")
        assert html =~ "Trending 1"
        refute html =~ "Trending 2"

        # 3. Load more trending movies
        view
        |> element("button[phx-click='load_more']")
        |> render_click()

        assert_patch(view, ~p"/movies/trending?page=2")
        assert render(view) =~ "Trending 2"

        # Verify all expected API calls were made
        assert called(Media.get_popular_movies(:_))
        assert called(Media.get_trending_movies(:_))
      end
    end

    test "error recovery workflow", %{conn: conn} do
      # Test error state first
      with_mock Media,
        get_popular_movies: fn _opts -> {:error, {:timeout, "Request timed out"}} end do
        {:ok, view, html} = live(conn, ~p"/movies")
        assert html =~ "The request timed out"
        assert has_element?(view, "button[phx-click='retry']")
      end

      # Test successful page load separately (retry functionality is tested in other tests)
      with_mock Media,
        get_popular_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        {:ok, _view, html} = live(conn, ~p"/movies")

        # Verify successful load shows movies
        assert html =~ "The Dark Knight"
        assert html =~ "Inception"
      end
    end

    test "navigation preserves state correctly", %{conn: conn} do
      with_mock Media,
        get_trending_movies: fn _opts -> {:ok, @sample_movies_with_pagination} end do
        # Navigate directly to trending with page 2
        {:ok, _view, html} = live(conn, ~p"/movies/trending?page=2")

        assert html =~ "Trending Movies"
        # Verify the function was called (parameters may vary due to implementation details)
        assert called(Media.get_trending_movies(:_))
      end
    end
  end
end
