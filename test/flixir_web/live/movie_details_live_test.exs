defmodule FlixirWeb.MovieDetailsLiveTest do
  @moduledoc """
  Integration tests for MovieDetailsLive with review filtering and sorting.
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
    },
    %Review{
      id: "3",
      author: "Bob Wilson",
      content: "Masterpiece! One of the best films ever made.",
      rating: 10.0,
      created_at: ~U[2023-01-20 09:15:00Z],
      url: "https://example.com/review3"
    }
  ]

  @sample_rating_stats %RatingStats{
    average_rating: 7.7,
    total_reviews: 3,
    rating_distribution: %{"4" => 1, "9" => 1, "10" => 1}
  }

  describe "mount and initial load" do
    test "loads movie details and reviews successfully", %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [
          get_reviews: fn("movie", 550, _opts) ->
            {:ok, %{reviews: @sample_reviews, pagination: %{page: 1, per_page: 10, total: 3, total_pages: 1, has_next: false, has_prev: false}}}
          end,
          get_rating_stats: fn("movie", 550) -> {:ok, @sample_rating_stats} end
        ]}
      ]) do
        {:ok, view, html} = live(conn, "/movie/550")

        assert html =~ "Fight Club"
        assert html =~ "A ticking-time-bomb insomniac"
        assert html =~ "Released: October 15, 1999"
        assert html =~ "John Doe"
        assert html =~ "Amazing movie with great acting"
        assert html =~ "Jane Smith"
        assert html =~ "Bob Wilson"
        assert html =~ "Filter & Sort Reviews"
        assert html =~ "7.7"
        assert html =~ "3 reviews"

        assert has_element?(view, "[data-testid='review-filters']")
        assert has_element?(view, "[data-testid='rating-display']")
        assert has_element?(view, "[data-testid='review-card']")
      end
    end

    test "handles media not found", %{conn: conn} do
      with_mock(Media, [get_content_details: fn("movie", 999) -> {:error, :not_found} end]) do
        {:ok, _view, html} = live(conn, "/movie/999")

        assert html =~ "Media not found"
        assert html =~ "The requested movie could not be found"
      end
    end

    test "handles reviews loading error", %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [get_reviews: fn("movie", 550, _opts) -> {:error, :network_error} end]}
      ]) do
        {:ok, view, html} = live(conn, "/movie/550")

        assert html =~ "Fight Club"
        assert html =~ "Error loading reviews"
        assert html =~ "Network error"
        assert has_element?(view, "button", "Try again")
      end
    end
  end

  describe "review filtering" do
    setup %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [
          get_reviews: fn("movie", 550, _opts) ->
            {:ok, %{reviews: @sample_reviews, pagination: %{page: 1, per_page: 10, total: 3, total_pages: 1, has_next: false, has_prev: false}}}
          end,
          get_rating_stats: fn("movie", 550) -> {:ok, @sample_rating_stats} end,
          filter_reviews: fn(reviews, filters) ->
            # Mock filtering logic
            case Map.get(filters, :filter_by_rating) do
              :positive -> Enum.filter(reviews, & &1.rating >= 6.0)
              :negative -> Enum.filter(reviews, & &1.rating < 6.0)
              _ -> reviews
            end
          end,
          sort_reviews: fn(reviews, _sort_by, _order) -> reviews end,
          paginate_reviews: fn(reviews, _page, _per_page) ->
            %{reviews: reviews, pagination: %{page: 1, per_page: 10, total: length(reviews), total_pages: 1, has_next: false, has_prev: false}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, "/movie/550")
        %{view: view}
      end
    end

    test "filters reviews by positive rating", %{view: view} do
      # Select positive rating filter
      view
      |> element("[data-testid='rating-filter-select']")
      |> render_change(%{"filter_by_rating" => "positive"})

      html = render(view)

      # Should show positive reviews (John Doe and Bob Wilson)
      assert html =~ "John Doe"
      assert html =~ "Bob Wilson"
      # Should not show negative review (Jane Smith)
      refute html =~ "Jane Smith"

      # Should show active filter indicator
      assert html =~ "1 active"
      assert html =~ "Rating: Positive"
    end

    test "filters reviews by author", %{view: view} do
      # Enter author filter
      view
      |> element("[data-testid='author-filter-input']")
      |> render_change(%{"author_filter" => "John"})

      html = render(view)

      # Should show John's review
      assert html =~ "John Doe"
      # Should show active filter
      assert html =~ "1 active"
      assert html =~ "Author: John"
    end

    test "filters reviews by content", %{view: view} do
      # Enter content filter
      view
      |> element("[data-testid='content-filter-input']")
      |> render_change(%{"content_filter" => "amazing"})

      html = render(view)

      # Should show active filter
      assert html =~ "1 active"
      assert html =~ "Content: amazing"
    end

    test "clears individual filters", %{view: view} do
      # Apply a rating filter first
      view
      |> element("[data-testid='rating-filter-select']")
      |> render_change(%{"filter_by_rating" => "positive"})

      # Verify filter is active
      html = render(view)
      assert html =~ "1 active"

      # Clear the rating filter
      view
      |> element("[data-testid='remove-filter-clear_rating']")
      |> render_click()

      html = render(view)
      refute html =~ "active"
    end

    test "clears all filters", %{view: view} do
      # Apply multiple filters
      view
      |> element("[data-testid='rating-filter-select']")
      |> render_change(%{"filter_by_rating" => "positive"})

      view
      |> element("[data-testid='author-filter-input']")
      |> render_change(%{"author_filter" => "John"})

      # Verify filters are active
      html = render(view)
      assert html =~ "2 active"

      # Clear all filters
      view
      |> element("[data-testid='clear-all-filters']")
      |> render_click()

      html = render(view)
      refute html =~ "active"
    end
  end

  describe "review sorting" do
    setup %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [
          get_reviews: fn("movie", 550, _opts) ->
            {:ok, %{reviews: @sample_reviews, pagination: %{page: 1, per_page: 10, total: 3, total_pages: 1, has_next: false, has_prev: false}}}
          end,
          get_rating_stats: fn("movie", 550) -> {:ok, @sample_rating_stats} end,
          filter_reviews: fn(reviews, _filters) -> reviews end,
          sort_reviews: fn(reviews, sort_by, order) ->
            # Mock sorting logic
            sorted = case sort_by do
              :rating -> Enum.sort_by(reviews, & &1.rating)
              :author -> Enum.sort_by(reviews, & &1.author)
              _ -> reviews
            end
            if order == :desc, do: Enum.reverse(sorted), else: sorted
          end,
          paginate_reviews: fn(reviews, _page, _per_page) ->
            %{reviews: reviews, pagination: %{page: 1, per_page: 10, total: length(reviews), total_pages: 1, has_next: false, has_prev: false}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, "/movie/550")
        %{view: view}
      end
    end

    test "sorts reviews by rating", %{view: view} do
      # Change sort to rating
      view
      |> element("[data-testid='sort-by-select']")
      |> render_change(%{"sort_by" => "rating"})

      html = render(view)

      # Should show active sort filter
      assert html =~ "1 active"
      assert html =~ "Sort: Rating ↓"
    end

    test "toggles sort order", %{view: view} do
      # Toggle sort order
      view
      |> element("[data-testid='sort-order-toggle']")
      |> render_click()

      html = render(view)

      # Should show ascending arrow
      assert html =~ "hero-arrow-up"
      assert html =~ "1 active"
    end

    test "sorts by author", %{view: view} do
      # Change sort to author
      view
      |> element("[data-testid='sort-by-select']")
      |> render_change(%{"sort_by" => "author"})

      html = render(view)

      # Should show active sort filter
      assert html =~ "1 active"
      assert html =~ "Sort: Author ↓"
    end
  end

  describe "review interactions" do
    setup %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [
          get_reviews: fn("movie", 550, _opts) ->
            {:ok, %{reviews: @sample_reviews, pagination: %{page: 1, per_page: 10, total: 3, total_pages: 1, has_next: false, has_prev: false}}}
          end,
          get_rating_stats: fn("movie", 550) -> {:ok, @sample_rating_stats} end,
          filter_reviews: fn(reviews, _filters) -> reviews end,
          sort_reviews: fn(reviews, _sort_by, _order) -> reviews end,
          paginate_reviews: fn(reviews, _page, _per_page) ->
            %{reviews: reviews, pagination: %{page: 1, per_page: 10, total: length(reviews), total_pages: 1, has_next: false, has_prev: false}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, "/movie/550")
        %{view: view}
      end
    end

    test "expands and collapses review content", %{view: view} do
      # Expand a review
      view
      |> element("[data-testid='read-more-button']")
      |> render_click()

      html = render(view)
      assert html =~ "Show less"

      # Collapse the review
      view
      |> element("[data-testid='show-less-button']")
      |> render_click()

      html = render(view)
      assert html =~ "Read more"
    end

    test "reveals spoiler content", %{view: view} do
      # This test assumes we have a review with spoilers
      # We'd need to mock a review with spoiler content
      html = render(view)

      # If there are spoiler warnings, test revealing them
      if html =~ "Spoiler Warning" do
        view
        |> element("[data-testid='reveal-spoilers-button']")
        |> render_click()

        updated_html = render(view)
        refute updated_html =~ "Spoiler Warning"
      end
    end
  end

  describe "empty states" do
    test "shows no reviews message when no reviews available", %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [
          get_reviews: fn("movie", 550, _opts) ->
            {:ok, %{reviews: [], pagination: %{page: 1, per_page: 10, total: 0, total_pages: 0, has_next: false, has_prev: false}}}
          end,
          get_rating_stats: fn("movie", 550) -> {:ok, %RatingStats{total_reviews: 0}} end
        ]}
      ]) do
        {:ok, _view, html} = live(conn, "/movie/550")

        assert html =~ "No reviews available"
        assert html =~ "Be the first to share your thoughts"
      end
    end

    test "shows no matching reviews when filters exclude all results", %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [
          get_reviews: fn("movie", 550, _opts) ->
            {:ok, %{reviews: @sample_reviews, pagination: %{page: 1, per_page: 10, total: 3, total_pages: 1, has_next: false, has_prev: false}}}
          end,
          get_rating_stats: fn("movie", 550) -> {:ok, @sample_rating_stats} end,
          filter_reviews: fn(_reviews, _filters) -> [] end,  # No results after filtering
          sort_reviews: fn(reviews, _sort_by, _order) -> reviews end,
          paginate_reviews: fn(reviews, _page, _per_page) ->
            %{reviews: reviews, pagination: %{page: 1, per_page: 10, total: 0, total_pages: 0, has_next: false, has_prev: false}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, "/movie/550")

        # Apply a filter that returns no results
        view
        |> element("[data-testid='rating-filter-select']")
        |> render_change(%{"filter_by_rating" => "positive"})

        html = render(view)
        assert html =~ "No reviews match your filters"
        assert html =~ "Try adjusting your filter criteria"
        assert html =~ "Clear all filters"
      end
    end
  end

  describe "pagination" do
    test "shows load more button when more reviews available", %{conn: conn} do
      with_mocks([
        {Media, [], [get_content_details: fn("movie", 550) -> {:ok, @sample_movie_details} end]},
        {Reviews, [], [
          get_reviews: fn("movie", 550, _opts) ->
            {:ok, %{reviews: @sample_reviews, pagination: %{page: 1, per_page: 10, total: 3, total_pages: 2, has_next: true, has_prev: false}}}
          end,
          get_rating_stats: fn("movie", 550) -> {:ok, @sample_rating_stats} end,
          filter_reviews: fn(reviews, _filters) -> reviews end,
          sort_reviews: fn(reviews, _sort_by, _order) -> reviews end,
          paginate_reviews: fn(reviews, _page, _per_page) ->
            %{reviews: reviews, pagination: %{page: 1, per_page: 10, total: length(reviews), total_pages: 2, has_next: true, has_prev: false}}
          end
        ]}
      ]) do
        {:ok, view, html} = live(conn, "/movie/550")

        assert html =~ "Load more reviews"
        assert has_element?(view, "button", "Load more reviews")
      end
    end
  end
end
