defmodule FlixirWeb.MovieListComponentsTest do
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
      assert html =~ "movie-lists-container"
      assert html =~ "list-navigation"
      assert html =~ "movie-grid"
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
    end
  end

  describe "list_navigation/1" do
    test "renders all navigation tabs" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :popular
        })

      assert html =~ "Popular"
      assert html =~ "Trending"
      assert html =~ "Top Rated"
      assert html =~ "Upcoming"
      assert html =~ "Now Playing"
      assert html =~ "nav-tab-popular"
      assert html =~ "nav-tab-trending"
    end

    test "highlights current active tab" do
      html =
        render_component(&list_navigation/1, %{
          current_list: :trending
        })

      # Should contain active styling for trending tab
      assert html =~ "border-blue-500 text-blue-600"
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
    end

    test "handles missing poster gracefully" do
      movie = sample_movie(%{poster_path: nil})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      assert html =~ "/images/no-poster.svg"
    end

    test "handles missing overview gracefully" do
      movie = sample_movie(%{overview: nil})

      html =
        render_component(&movie_card/1, %{
          movie: movie,
          current_list: :popular
        })

      # Should still render the card without overview
      assert html =~ "movie-card"
      assert html =~ "Test Movie"
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
