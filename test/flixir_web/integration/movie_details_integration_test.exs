defmodule FlixirWeb.MovieDetailsIntegrationTest do
  @moduledoc """
  Integration test for MovieDetailsLive to verify the basic functionality works.
  """

  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.{Media, Reviews}
  alias Flixir.Reviews.{Review, RatingStats}

  @sample_movie_details %{
    "id" => 550,
    "title" => "Fight Club",
    "overview" => "A ticking-time-bomb insomniac and a slippery soap salesman...",
    "release_date" => "1999-10-15",
    "poster_path" => "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg"
  }

  @sample_reviews [
    %Review{
      id: "1",
      author: "John Doe",
      content: "Amazing movie with great acting and plot twists!",
      rating: 9.0,
      created_at: ~U[2023-01-15 10:00:00Z],
      url: "https://example.com/review1"
    },
    %Review{
      id: "2",
      author: "Jane Smith",
      content: "Not my cup of tea. Too violent and confusing.",
      rating: 4.0,
      created_at: ~U[2023-01-10 15:30:00Z],
      url: "https://example.com/review2"
    }
  ]

  @sample_rating_stats %RatingStats{
    average_rating: 6.5,
    total_reviews: 2,
    rating_distribution: %{"4" => 1, "9" => 1}
  }

  test "basic movie details page loads with reviews", %{conn: conn} do
    with_mocks([
      {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
      {Reviews, [], [
        get_reviews: fn("movie", 550, _opts) ->
          {:ok, %{reviews: @sample_reviews, pagination: %{page: 1, per_page: 10, total: 2, total_pages: 1, has_next: false, has_prev: false}}}
        end,
        get_rating_stats: fn("movie", 550) -> {:ok, @sample_rating_stats} end,
        filter_reviews: fn(reviews, _filters) -> reviews end,
        sort_reviews: fn(reviews, _sort_by, _order) -> reviews end,
        paginate_reviews: fn(reviews, _page, _per_page) ->
          %{reviews: reviews, pagination: %{page: 1, per_page: 10, total: length(reviews), total_pages: 1, has_next: false, has_prev: false}}
        end
      ]}
    ]) do
      {:ok, _view, html} = live(conn, "/movie/550")

      # Basic page elements
      assert html =~ "Fight Club"
      assert html =~ "A ticking-time-bomb insomniac"
      assert html =~ "Released: October 15, 1999"

      # Reviews content
      assert html =~ "John Doe"
      assert html =~ "Amazing movie with great acting"
      assert html =~ "Jane Smith"
      assert html =~ "Not my cup of tea"

      # Rating stats
      assert html =~ "6.5"
      assert html =~ "2 reviews"

      # Filter controls
      assert html =~ "Filter & Sort Reviews"
    end
  end
end
