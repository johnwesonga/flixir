defmodule FlixirWeb.MovieListComponentsTest do
  @moduledoc """
  Tests for movie list UI components.

  This test suite covers all movie list components including rendering with different
  movie data, loading states, error states, empty states, responsive behavior,
  and accessibility features.
  """

  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import FlixirWeb.MovieListComponents

  alias Flixir.Media.SearchResult

  describe "movie_lists_container/1" do
    test "renders container with navigation and content" do
      movies = [sample_movie()]

      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: movies,
          loading: false,
          error: nil,
          has_more: true,
          page: 1
        })

      assert html =~ "Movies"
      assert html =~ "Discover popular movies, trending content, and upcoming releases"
      assert html =~ "movie-lists-container"
      assert html =~ "list-navigation"
      assert html =~ "movie-grid"
      assert html =~ "load-more-section"
    end

    test "renders loading state when loading and no movies" do
      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: [],
          loading: true,
          error: nil,
          has_more: false,
          page: 1
        })

      assert html =~ "Loading movies..."
      assert html =~ "loading-state"
      assert html =~ "skeleton-movie-card"
      refute html =~ "movie-grid"
      refute html =~ "load-more-section"
    end

    test "renders error state when error present" do
      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: [],
          loading: false,
          error: "API Error",
          has_more: false,
          page: 1
        })

      assert html =~ "Something went wrong"
      assert html =~ "error-state"
      assert html =~ "Try Again"
      assert html =~ "phx-click=\"retry\""
      refute html =~ "movie-grid"
      refute html =~ "loading-state"
    end

    test "renders empty state when no movies and not loading" do
      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: [],
          loading: false,
          error: nil,
          has_more: false,
          page: 1
        })

      assert html =~ "No movies found"
      assert html =~ "empty-state"
      assert html =~ "popular movies"
      assert html =~ "phx-click=\"retry\""
      refute html =~ "movie-grid"
      refute html =~ "loading-state"
    end

    test "renders movies with load more when has_more is true" do
      movies = [sample_movie(), sample_movie(%{id: 2, title: "Movie 2"})]

      html =
        render_component(&movie_lists_container/1, %{
          current_list: :trending,
          movies: movies,
          loading: false,
          error: nil,
          has_more: true,
          page: 2
        })

      assert html =~ "movie-grid"
      assert html =~ "load-more-section"
      assert html =~ "Load More Movies"
      assert html =~ "phx-value-page=\"3\""
    end

    test "does not render load more when has_more is false" do
      movies = [sample_movie()]

      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: movies,
          loading: false,
          error: nil,
          has_more: false,
          page: 1
        })

      assert html =~ "movie-grid"
      refute html =~ "load-more-section"
    end

    test "applies custom CSS classes" do
      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: [],
          loading: false,
          error: nil,
          has_more: false,
          page: 1,
          class: "custom-container-class"
        })

      assert html =~ "custom-container-class"
    end

    test "renders loading more state in load more section" do
      movies = [sample_movie()]

      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: movies,
          loading: true,
          error: nil,
          has_more: true,
          page: 1
        })

      assert html =~ "movie-grid"
      assert html =~ "Loading more movies..."
      assert html =~ "animate-spin"
      refute html =~ "Load More Movies"
    end
  end

  describe "list_navigation/1" do
    test "renders all navigation tabs with proper labels and descriptions" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :popular
        })

      assert html =~ "Popular"
      assert html =~ "Most popular movies"
      assert html =~ "Trending"
      assert html =~ "Trending this week"
      assert html =~ "Top Rated"
      assert html =~ "Highest rated movies"
      assert html =~ "Upcoming"
      assert html =~ "Coming soon"
      assert html =~ "Now Playing"
      assert html =~ "In theaters now"
      assert html =~ "nav-tab-popular"
      assert html =~ "nav-tab-trending"
      assert html =~ "nav-tab-top_rated"
      assert html =~ "nav-tab-upcoming"
      assert html =~ "nav-tab-now_playing"
    end

    test "highlights current active tab with proper styling" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :trending
        })

      assert html =~ "border-blue-500 text-blue-600"
      # Ensure inactive tabs have different styling
      assert html =~ "border-transparent text-gray-500"
    end

    test "generates correct navigation links for each tab" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :popular
        })

      assert html =~ ~s(href="/movies/popular")
      assert html =~ ~s(href="/movies/trending")
      assert html =~ ~s(href="/movies/top_rated")
      assert html =~ ~s(href="/movies/upcoming")
      assert html =~ ~s(href="/movies/now_playing")
    end

    test "applies custom CSS classes" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :popular,
          class: "custom-nav-class"
        })

      assert html =~ "custom-nav-class"
    end

    test "includes proper accessibility attributes" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :popular
        })

      assert html =~ "list-navigation"
      assert html =~ "data-testid=\"list-navigation\""
      # Check for proper navigation structure
      assert html =~ "<nav"
    end

    test "handles all list types correctly" do
      for list_type <- [:popular, :trending, :top_rated, :upcoming, :now_playing] do
        html =
          render_component(&list_navigation/1, %{
            current_list: list_type
          })

        assert html =~ "border-blue-500 text-blue-600"
        assert html =~ "data-testid=\"nav-tab-#{list_type}\""
      end
    end
  end

  describe "movie_grid/1" do
    test "renders grid with movie cards" do
      movies = [sample_movie(), sample_movie(%{id: 2, title: "Another Movie"})]

      html =
        render_component(&movie_grid/1, %{
          movies: movies,
          current_list: :popular
        })

      assert html =~ "movie-grid"
      assert html =~ "movie-card"
      assert html =~ "Test Movie"
      assert html =~ "Another Movie"
    end

    test "renders empty grid when no movies" do
      html =
        render_component(&movie_grid/1, %{
          movies: [],
          current_list: :popular
        })

      assert html =~ "movie-grid"
      refute html =~ "movie-card"
    end

    test "applies responsive grid classes" do
      movies = [sample_movie()]

      html =
        render_component(&movie_grid/1, %{
          movies: movies,
          current_list: :popular
        })

      assert html =~ "grid-cols-1"
      assert html =~ "sm:grid-cols-2"
      assert html =~ "md:grid-cols-3"
      assert html =~ "lg:grid-cols-4"
      assert html =~ "xl:grid-cols-5"
      assert html =~ "gap-6"
    end

    test "applies custom CSS classes" do
      html =
        render_component(&movie_grid/1, %{
          movies: [],
          current_list: :popular,
          class: "custom-grid-class"
        })

      assert html =~ "custom-grid-class"
    end

    test "renders multiple movies with different data" do
      movies = [
        sample_movie(%{id: 1, title: "Action Movie", vote_average: 8.5}),
        sample_movie(%{id: 2, title: "Comedy Movie", vote_average: 7.2, poster_path: nil}),
        sample_movie(%{id: 3, title: "Drama Movie", overview: nil})
      ]

      html =
        render_component(&movie_grid/1, %{
          movies: movies,
          current_list: :top_rated
        })

      assert html =~ "Action Movie"
      assert html =~ "Comedy Movie"
      assert html =~ "Drama Movie"
      assert html =~ "8.5"
      assert html =~ "7.2"
      assert html =~ "/images/no-poster.svg"
    end

    test "includes proper accessibility attributes" do
      movies = [sample_movie()]

      html =
        render_component(&movie_grid/1, %{
          movies: movies,
          current_list: :popular
        })

      assert html =~ "data-testid=\"movie-grid\""
    end
  end

  describe "movie_card/1" do
    test "renders movie card with all information" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "movie-card"
      assert html =~ "Test Movie"
      assert html =~ "2023"
      assert html =~ "A great test movie"
      assert html =~ "/movie/1"
      assert html =~ "from=popular"
    end

    test "renders rating badge when rating available" do
      movie = sample_movie(%{vote_average: 8.5})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "rating-badge"
      assert html =~ "8.5"
      assert html =~ "text-yellow-400"
    end

    test "does not render rating badge when rating is zero" do
      movie = sample_movie(%{vote_average: 0})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      refute html =~ "rating-badge"
    end

    test "renders list indicator for trending movies" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :trending
        })

      assert html =~ "list-indicator"
      assert html =~ "Trending"
      assert html =~ "bg-green-500"
    end

    test "renders list indicator for upcoming movies" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :upcoming
        })

      assert html =~ "list-indicator"
      assert html =~ "Coming Soon"
      assert html =~ "bg-purple-500"
    end

    test "does not render list indicator for other list types" do
      movie = sample_movie()

      for list_type <- [:popular, :top_rated, :now_playing] do
        html =
          render_component(&movie_card/1, %{
            movie: movie,
            current_list: list_type
          })

        refute html =~ "list-indicator"
      end
    end

    test "handles missing poster gracefully" do
      movie = sample_movie(%{poster_path: nil})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "/images/no-poster.svg"
      assert html =~ ~s(onerror="this.src='/images/no-poster.svg'")
    end

    test "handles missing overview gracefully" do
      movie = sample_movie(%{overview: nil})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      # Should still render the card without overview content
      assert html =~ "movie-card"
      assert html =~ "Test Movie"
      # The overview section should be empty but the structure might still exist
      refute html =~ "line-clamp-3"
    end

    test "handles missing release date gracefully" do
      movie = sample_movie(%{release_date: nil})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "Unknown"
    end

    test "renders popularity badge for high popularity movies" do
      movie = sample_movie(%{popularity: 150.0})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "Popular"
      assert html =~ "bg-blue-100 text-blue-800"
    end

    test "does not render popularity badge for low popularity movies" do
      movie = sample_movie(%{popularity: 50.0})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      refute html =~ "Popular"
    end

    test "includes proper accessibility attributes" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "data-testid=\"movie-card\""
      assert html =~ ~s(alt="Test Movie poster")
      assert html =~ ~s(title="Test Movie")
      assert html =~ "loading=\"lazy\""
      assert html =~ "decoding=\"async\""
    end

    test "includes responsive image attributes" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "srcset="
      assert html =~ "sizes="
      assert html =~ "185w"
      assert html =~ "300w"
      assert html =~ "500w"
    end

    test "applies hover effects and transitions" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "hover:shadow-lg"
      assert html =~ "hover:-translate-y-1"
      assert html =~ "group-hover:scale-105"
      assert html =~ "group-hover:text-blue-600"
      assert html =~ "transition-all"
      assert html =~ "transition-transform"
      assert html =~ "transition-colors"
    end

    test "truncates long overview text" do
      long_overview = String.duplicate("This is a very long overview text. ", 10)
      movie = sample_movie(%{overview: long_overview})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "line-clamp-3"
      assert html =~ "..."
    end

    test "truncates long title with proper title attribute" do
      long_title = "This is a Very Long Movie Title That Should Be Truncated Properly in the UI"
      movie = sample_movie(%{title: long_title})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "line-clamp-2"
      assert html =~ ~s(title="#{long_title}")
    end

    test "applies custom CSS classes" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular,
          class: "custom-card-class"
        })

      assert html =~ "custom-card-class"
    end

    test "handles different date formats" do
      # Test with string date
      movie_with_string_date = sample_movie(%{release_date: "2023-12-25"})

      html =
        render_component(&movie_card/1, %{
          movie: movie_with_string_date,
          current_list: :popular
        })

      assert html =~ "2023"

      # Test with invalid date string
      movie_with_invalid_date = sample_movie(%{release_date: "invalid-date"})

      html =
        render_component(&movie_card/1, %{
          movie: movie_with_invalid_date,
          current_list: :popular
        })

      assert html =~ "Unknown"
    end
  end

  describe "loading states" do
    test "renders skeleton cards with proper animation" do
      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: [],
          loading: true,
          error: nil,
          has_more: false,
          page: 1
        })

      assert html =~ "skeleton-movie-card"
      assert html =~ "animate-pulse"
      assert html =~ "bg-gray-300"
      # Should render 20 skeleton cards
      skeleton_count = html |> String.split("skeleton-movie-card") |> length()
      assert skeleton_count == 21  # 20 cards + 1 for the split
    end

    test "renders loading spinner in load more section" do
      movies = [sample_movie()]

      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: movies,
          loading: true,
          error: nil,
          has_more: true,
          page: 1
        })

      assert html =~ "Loading more movies..."
      assert html =~ "animate-spin"
      assert html =~ "opacity-25"
      assert html =~ "opacity-75"
    end
  end

  describe "error states" do
    test "renders different error messages for different error types" do
      error_cases = [
        {:timeout, "The request timed out"},
        {:rate_limited, "Too many requests"},
        {:unauthorized, "Unable to access movie data"},
        {:network_error, "Network connection error"},
        {:api_error, "Unable to load movies from the service"},
        {"Custom error message", "Custom error message"},
        {:unknown_error, "An unexpected error occurred"}
      ]

      for {error, expected_message} <- error_cases do
        html =
          render_component(&movie_lists_container/1, %{
            current_list: :popular,
            movies: [],
            loading: false,
            error: error,
            has_more: false,
            page: 1
          })

        assert html =~ expected_message
        assert html =~ "error-state"
        assert html =~ "text-red-500"
        assert html =~ "bg-red-100"
        assert html =~ "phx-click=\"retry\""
      end
    end
  end

  describe "empty states" do
    test "renders appropriate empty state messages for different list types" do
      list_types_and_messages = [
        {:popular, "popular movies"},
        {:trending, "trending movies"},
        {:top_rated, "top rated movies"},
        {:upcoming, "upcoming movies"},
        {:now_playing, "now playing movies"}
      ]

      for {list_type, expected_message} <- list_types_and_messages do
        html =
          render_component(&movie_lists_container/1, %{
            current_list: list_type,
            movies: [],
            loading: false,
            error: nil,
            has_more: false,
            page: 1
          })

        assert html =~ expected_message
        assert html =~ "empty-state"
        assert html =~ "No movies found"
        assert html =~ "phx-click=\"retry\""
      end
    end
  end

  describe "responsive behavior" do
    test "movie grid applies responsive classes for different screen sizes" do
      movies = [sample_movie()]

      html =
        render_component(&movie_grid/1, %{
          movies: movies,
          current_list: :popular
        })

      # Test responsive grid classes
      assert html =~ "grid-cols-1"        # Mobile: 1 column
      assert html =~ "sm:grid-cols-2"     # Small: 2 columns
      assert html =~ "md:grid-cols-3"     # Medium: 3 columns
      assert html =~ "lg:grid-cols-4"     # Large: 4 columns
      assert html =~ "xl:grid-cols-5"     # Extra large: 5 columns
      assert html =~ "gap-6"              # Consistent gap
    end

    test "navigation includes overflow handling for mobile" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :popular
        })

      assert html =~ "overflow-x-auto"
      assert html =~ "whitespace-nowrap"
      assert html =~ "min-w-0"
    end

    test "movie cards include responsive image sizing" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      # Test responsive image sizes
      assert html =~ "sizes=\"(max-width: 640px) 50vw"
      assert html =~ "(max-width: 768px) 33vw"
      assert html =~ "(max-width: 1024px) 25vw"
      assert html =~ "20vw\""
    end
  end

  describe "accessibility features" do
    test "all components include proper ARIA attributes and semantic HTML" do
      movies = [sample_movie()]

      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: movies,
          loading: false,
          error: nil,
          has_more: true,
          page: 1
        })

      # Test semantic HTML structure
      assert html =~ "<nav"
      assert html =~ "<h1"
      assert html =~ "<h3"

      # Test data-testid attributes for testing
      assert html =~ "data-testid=\"movie-lists-container\""
      assert html =~ "data-testid=\"list-navigation\""
      assert html =~ "data-testid=\"movie-grid\""
      assert html =~ "data-testid=\"movie-card\""
      assert html =~ "data-testid=\"load-more-section\""
    end

    test "images include proper alt text and loading attributes" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ ~s(alt="Test Movie poster")
      assert html =~ "loading=\"lazy\""
      assert html =~ "decoding=\"async\""
    end

    test "buttons include proper accessibility attributes" do
      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: [],
          loading: false,
          error: "Test error",
          has_more: false,
          page: 1
        })

      # Error state retry button
      assert html =~ "phx-click=\"retry\""
      assert html =~ "Try Again"

      # Test with load more button
      movies = [sample_movie()]

      html =
        render_component(&movie_lists_container/1, %{
          current_list: :popular,
          movies: movies,
          loading: false,
          error: nil,
          has_more: true,
          page: 1
        })

      assert html =~ "Load More Movies"
      assert html =~ "phx-click=\"load_more\""
      assert html =~ "phx-value-page=\"2\""
    end

    test "navigation links include proper href attributes" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :popular
        })

      assert html =~ ~s(href="/movies/popular")
      assert html =~ ~s(href="/movies/trending")
      assert html =~ ~s(href="/movies/top_rated")
      assert html =~ ~s(href="/movies/upcoming")
      assert html =~ ~s(href="/movies/now_playing")
    end
  end

  describe "helper functions" do
    test "poster_url/2 handles different sizes and nil values" do
      movie_with_poster = sample_movie()
      movie_without_poster = sample_movie(%{poster_path: nil})

      # Test with poster
      html_with_poster =
        render_component(&movie_card/1, %{
          movie: movie_with_poster,
          current_list: :popular
        })

      assert html_with_poster =~ "https://image.tmdb.org/t/p/w185/test-poster.jpg"

      # Test without poster
      html_without_poster =
        render_component(&movie_card/1, %{
          movie: movie_without_poster,
          current_list: :popular
        })

      assert html_without_poster =~ "/images/no-poster.svg"
    end

    test "poster_srcset/1 generates proper responsive image sources" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "185w"
      assert html =~ "300w"
      assert html =~ "500w"
      assert html =~ "w185/test-poster.jpg 185w"
      assert html =~ "w300/test-poster.jpg 300w"
      assert html =~ "w500/test-poster.jpg 500w"
    end

    test "format_release_date/1 handles various date formats" do
      test_cases = [
        {~D[2023-05-15], "2023"},
        {"2023-12-25", "2023"},
        {"invalid-date", "Unknown"},
        {nil, "Unknown"},
        {"", "Unknown"}
      ]

      for {date_input, expected_output} <- test_cases do
        movie = sample_movie(%{release_date: date_input})

        html =
          render_component(&movie_card/1, %{
            movie: movie,
            current_list: :popular
          })

        assert html =~ expected_output
      end
    end

    test "truncate_text/2 handles text truncation properly" do
      # Test short text (no truncation)
      short_movie = sample_movie(%{overview: "Short overview"})

      html_short =
        render_component(&movie_card/1, %{
          movie: short_movie,
          current_list: :popular
        })

      assert html_short =~ "Short overview"
      refute html_short =~ "..."

      # Test long text (with truncation)
      long_text = String.duplicate("This is a very long overview text. ", 10)
      long_movie = sample_movie(%{overview: long_text})

      html_long =
        render_component(&movie_card/1, %{
          movie: long_movie,
          current_list: :popular
        })

      assert html_long =~ "..."

      # Test nil text
      nil_movie = sample_movie(%{overview: nil})

      html_nil =
        render_component(&movie_card/1, %{
          movie: nil_movie,
          current_list: :popular
        })

      # The overview section should not contain the overview text
      refute html_nil =~ "line-clamp-3"
    end

    test "list_type_label/1 returns correct labels for all list types" do
      list_types = [:popular, :trending, :top_rated, :upcoming, :now_playing]

      for list_type <- list_types do
        html =
          render_component(&movie_lists_container/1, %{
            current_list: list_type,
            movies: [],
            loading: false,
            error: nil,
            has_more: false,
            page: 1
          })

        case list_type do
          :popular -> assert html =~ "popular movies"
          :trending -> assert html =~ "trending movies"
          :top_rated -> assert html =~ "top rated movies"
          :upcoming -> assert html =~ "upcoming movies"
          :now_playing -> assert html =~ "now playing movies"
        end
      end
    end

    test "build_nav_params/1 includes proper navigation context" do
      movie = sample_movie()

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :trending
        })

      assert html =~ "from=trending"
    end
  end

  describe "edge cases and error handling" do
    test "handles movies with missing or invalid data gracefully" do
      problematic_movies = [
        sample_movie(%{title: ""}),
        sample_movie(%{vote_average: 0}),
        sample_movie(%{popularity: 0}),
        sample_movie(%{genre_ids: []})
      ]

      for movie <- problematic_movies do
        # Should not raise an error
        html =
          render_component(&movie_card/1, %{
            movie: movie,
            current_list: :popular
          })

        assert html =~ "movie-card"
      end
    end

    test "handles empty or malformed movie lists" do
      test_cases = [
        [],
        [sample_movie(%{title: "Valid Movie"})]
      ]

      for movies <- test_cases do
        # Should not raise an error
        html =
          render_component(&movie_grid/1, %{
            movies: movies,
            current_list: :popular
          })

        assert html =~ "movie-grid"
      end
    end

    test "handles very long movie titles and overviews" do
      extremely_long_title = String.duplicate("Very Long Title ", 50)
      extremely_long_overview = String.duplicate("Very long overview text. ", 100)

      movie = sample_movie(%{
        title: extremely_long_title,
        overview: extremely_long_overview
      })

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "line-clamp-2"
      assert html =~ "line-clamp-3"
      assert html =~ "..."
      assert html =~ ~s(title="#{extremely_long_title}")
    end

    test "handles special characters in movie data" do
      movie_with_special_chars = sample_movie(%{
        title: "Movie with \"Quotes\" & <Special> Characters",
        overview: "Overview with 'quotes' and <tags> & symbols"
      })

      html =
        render_component(&movie_card/1, %{
          movie: movie_with_special_chars,
          current_list: :popular
        })

      # Should properly escape HTML
      assert html =~ "movie-card"
      refute html =~ "<Special>"
      refute html =~ "<tags>"
    end
  end

  # Helper function to create sample movie data
  defp sample_movie(overrides \\ %{}) do
    base_movie = %SearchResult{
      id: 1,
      title: "Test Movie",
      media_type: :movie,
      release_date: ~D[2023-01-01],
      overview: "A great test movie for testing purposes.",
      poster_path: "/test-poster.jpg",
      genre_ids: [28, 12],
      vote_average: 7.5,
      popularity: 150.0
    }

    Map.merge(base_movie, overrides)
  end
end
