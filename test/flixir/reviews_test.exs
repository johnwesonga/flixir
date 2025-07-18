defmodule Flixir.ReviewsTest do
  use ExUnit.Case, async: true

  alias Flixir.Reviews
  alias Flixir.Reviews.{Review, RatingStats, Cache, TMDBClient}

  import Mock

  describe "get_reviews/3" do
    test "returns error for invalid media type" do
      assert {:error, :invalid_media_type} = Reviews.get_reviews("invalid", 123)
    end

    test "returns error for invalid media id" do
      assert {:error, :invalid_media_id} = Reviews.get_reviews("movie", 0)
      assert {:error, :invalid_media_id} = Reviews.get_reviews("movie", -1)
      assert {:error, :invalid_media_id} = Reviews.get_reviews("movie", "invalid")
    end

    test "returns cached reviews when available" do
      media_type = "movie"
      media_id = 550

      sample_reviews = [
        %Review{id: "1", author: "John", content: "Great movie!", rating: 8.0},
        %Review{id: "2", author: "Jane", content: "Not bad", rating: 6.0}
      ]

      with_mock Cache, [
        get_reviews: fn ^media_type, "550", %{} -> {:ok, sample_reviews} end
      ] do
        assert {:ok, result} = Reviews.get_reviews(media_type, media_id)

        assert %{reviews: reviews, pagination: pagination} = result
        assert length(reviews) == 2
        assert pagination.total == 2
        assert pagination.page == 1

        assert_called Cache.get_reviews(media_type, "550", %{})
      end
    end

    test "fetches from API when cache miss" do
      media_type = "movie"
      media_id = 550

      sample_reviews = [
        %Review{id: "1", author: "John", content: "Great movie!", rating: 8.0}
      ]

      api_response = %{reviews: sample_reviews, total_pages: 1, total_results: 1}

      with_mocks [
        {Cache, [], [
          get_reviews: fn ^media_type, "550", %{} -> :error end,
          put_reviews: fn ^media_type, "550", ^sample_reviews, %{} -> :ok end
        ]},
        {TMDBClient, [], [
          fetch_reviews: fn ^media_type, ^media_id, 1 -> {:ok, api_response} end
        ]}
      ] do
        assert {:ok, result} = Reviews.get_reviews(media_type, media_id)

        assert %{reviews: reviews, pagination: _pagination} = result
        assert length(reviews) == 1

        assert_called Cache.get_reviews(media_type, "550", %{})
        assert_called TMDBClient.fetch_reviews(media_type, media_id, 1)
        assert_called Cache.put_reviews(media_type, "550", sample_reviews, %{})
      end
    end

    test "handles API errors gracefully" do
      media_type = "movie"
      media_id = 550

      with_mocks [
        {Cache, [], [get_reviews: fn _, _, _ -> :error end]},
        {TMDBClient, [], [fetch_reviews: fn _, _, _ -> {:error, :timeout} end]}
      ] do
        assert {:error, :timeout} = Reviews.get_reviews(media_type, media_id)
      end
    end

    test "applies pagination correctly" do
      media_type = "movie"
      media_id = 550

      sample_reviews = Enum.map(1..25, fn i ->
        %Review{id: "#{i}", author: "User#{i}", content: "Review #{i}", rating: 5.0}
      end)

      with_mock Cache, [
        get_reviews: fn ^media_type, "550", %{} -> {:ok, sample_reviews} end
      ] do
        # Test first page
        assert {:ok, result} = Reviews.get_reviews(media_type, media_id, page: 1, per_page: 10)
        assert length(result.reviews) == 10
        assert result.pagination.page == 1
        assert result.pagination.total_pages == 3
        assert result.pagination.has_next == true
        assert result.pagination.has_prev == false

        # Test second page
        assert {:ok, result} = Reviews.get_reviews(media_type, media_id, page: 2, per_page: 10)
        assert length(result.reviews) == 10
        assert result.pagination.page == 2
        assert result.pagination.has_next == true
        assert result.pagination.has_prev == true

        # Test last page
        assert {:ok, result} = Reviews.get_reviews(media_type, media_id, page: 3, per_page: 10)
        assert length(result.reviews) == 5
        assert result.pagination.page == 3
        assert result.pagination.has_next == false
        assert result.pagination.has_prev == true
      end
    end

    test "validates and normalizes options" do
      media_type = "movie"
      media_id = 550

      with_mocks [
        {Cache, [], [
          get_reviews: fn _, _, _ -> :error end,
          put_reviews: fn _, _, _, _ -> :ok end
        ]},
        {TMDBClient, [], [fetch_reviews: fn _, _, _ -> {:ok, %{reviews: []}} end]}
      ] do
        # Invalid page
        assert {:error, :invalid_page} = Reviews.get_reviews(media_type, media_id, page: 0)
        assert {:error, :invalid_page} = Reviews.get_reviews(media_type, media_id, page: -1)

        # Invalid per_page
        assert {:error, :invalid_per_page} = Reviews.get_reviews(media_type, media_id, per_page: 0)
        assert {:error, :invalid_per_page} = Reviews.get_reviews(media_type, media_id, per_page: 100)

        # Invalid sort options
        assert {:error, :invalid_sort_by} = Reviews.get_reviews(media_type, media_id, sort_by: :invalid)
        assert {:error, :invalid_sort_order} = Reviews.get_reviews(media_type, media_id, sort_order: :invalid)
      end
    end
  end

  describe "get_rating_stats/2" do
    test "returns error for invalid media type" do
      assert {:error, :invalid_media_type} = Reviews.get_rating_stats("invalid", 123)
    end

    test "returns error for invalid media id" do
      assert {:error, :invalid_media_id} = Reviews.get_rating_stats("movie", 0)
    end

    test "returns cached rating stats when available" do
      media_type = "movie"
      media_id = 550

      {:ok, sample_stats} = RatingStats.new(%{
        average_rating: 7.5,
        total_reviews: 100,
        rating_distribution: %{"7" => 30, "8" => 50, "9" => 20}
      })

      with_mock Cache, [
        get_ratings: fn ^media_type, "550" -> {:ok, sample_stats} end
      ] do
        assert {:ok, stats} = Reviews.get_rating_stats(media_type, media_id)
        assert stats.average_rating == 7.5
        assert stats.total_reviews == 100

        assert_called Cache.get_ratings(media_type, "550")
      end
    end

    test "fetches and calculates stats from API when cache miss" do
      media_type = "movie"
      media_id = 550

      sample_reviews = [
        %Review{id: "1", author: "John", content: "Great!", rating: 8.0},
        %Review{id: "2", author: "Jane", content: "Good", rating: 7.0},
        %Review{id: "3", author: "Bob", content: "Okay", rating: nil}
      ]

      api_response = %{reviews: sample_reviews}

      with_mocks [
        {Cache, [], [
          get_ratings: fn ^media_type, "550" -> :error end,
          put_ratings: fn ^media_type, "550", _stats -> :ok end
        ]},
        {TMDBClient, [], [
          fetch_reviews: fn ^media_type, ^media_id, 1 -> {:ok, api_response} end
        ]}
      ] do
        assert {:ok, stats} = Reviews.get_rating_stats(media_type, media_id)

        assert stats.total_reviews == 3
        assert stats.average_rating == 7.5  # (8.0 + 7.0) / 2
        assert stats.rating_distribution == %{"8" => 1, "7" => 1}

        assert_called Cache.get_ratings(media_type, "550")
        assert_called TMDBClient.fetch_reviews(media_type, media_id, 1)
        assert_called Cache.put_ratings(media_type, "550", stats)
      end
    end
  end

  describe "filter_reviews/2" do
    setup do
      reviews = [
        %Review{id: "1", author: "John Doe", content: "Amazing movie!", rating: 9.0},
        %Review{id: "2", author: "Jane Smith", content: "Pretty good film", rating: 7.0},
        %Review{id: "3", author: "Bob Wilson", content: "Terrible movie", rating: 2.0},
        %Review{id: "4", author: "Alice Brown", content: "Decent film", rating: nil}
      ]

      {:ok, reviews: reviews}
    end

    test "filters by positive rating", %{reviews: reviews} do
      filtered = Reviews.filter_reviews(reviews, %{filter_by_rating: :positive})

      assert length(filtered) == 2
      assert Enum.all?(filtered, fn review -> review.rating && review.rating >= 6.0 end)
    end

    test "filters by negative rating", %{reviews: reviews} do
      filtered = Reviews.filter_reviews(reviews, %{filter_by_rating: :negative})

      assert length(filtered) == 1
      assert hd(filtered).rating == 2.0
    end

    test "filters by rating range", %{reviews: reviews} do
      filtered = Reviews.filter_reviews(reviews, %{filter_by_rating: {6.0, 8.0}})

      assert length(filtered) == 1
      assert hd(filtered).rating == 7.0
    end

    test "filters by author name", %{reviews: reviews} do
      filtered = Reviews.filter_reviews(reviews, %{author_filter: "john"})

      assert length(filtered) == 1
      assert hd(filtered).author == "John Doe"
    end

    test "filters by content keywords", %{reviews: reviews} do
      filtered = Reviews.filter_reviews(reviews, %{content_filter: "movie"})

      assert length(filtered) == 2
      assert Enum.any?(filtered, &String.contains?(&1.content, "Amazing movie"))
      assert Enum.any?(filtered, &String.contains?(&1.content, "Terrible movie"))
    end

    test "applies multiple filters", %{reviews: reviews} do
      filters = %{
        filter_by_rating: :positive,
        content_filter: "film"
      }

      filtered = Reviews.filter_reviews(reviews, filters)

      assert length(filtered) == 1
      assert hd(filtered).author == "Jane Smith"
    end

    test "returns all reviews when no filters applied", %{reviews: reviews} do
      filtered = Reviews.filter_reviews(reviews, %{})
      assert length(filtered) == 4
    end
  end

  describe "sort_reviews/3" do
    setup do
      {:ok, date1, _} = DateTime.from_iso8601("2023-01-01T00:00:00Z")
      {:ok, date2, _} = DateTime.from_iso8601("2023-01-02T00:00:00Z")
      {:ok, date3, _} = DateTime.from_iso8601("2023-01-03T00:00:00Z")

      reviews = [
        %Review{id: "1", author: "Charlie", content: "Review 1", rating: 7.0, created_at: date2},
        %Review{id: "2", author: "Alice", content: "Review 2", rating: 9.0, created_at: date1},
        %Review{id: "3", author: "Bob", content: "Review 3", rating: 5.0, created_at: date3}
      ]

      {:ok, reviews: reviews}
    end

    test "sorts by date descending (default)", %{reviews: reviews} do
      sorted = Reviews.sort_reviews(reviews, :date)

      dates = Enum.map(sorted, & &1.created_at)
      assert dates == Enum.sort(dates, {:desc, DateTime})
    end

    test "sorts by date ascending", %{reviews: reviews} do
      sorted = Reviews.sort_reviews(reviews, :date, :asc)

      dates = Enum.map(sorted, & &1.created_at)
      assert dates == Enum.sort(dates, {:asc, DateTime})
    end

    test "sorts by rating descending", %{reviews: reviews} do
      sorted = Reviews.sort_reviews(reviews, :rating, :desc)

      ratings = Enum.map(sorted, & &1.rating)
      assert ratings == [9.0, 7.0, 5.0]
    end

    test "sorts by rating ascending", %{reviews: reviews} do
      sorted = Reviews.sort_reviews(reviews, :rating, :asc)

      ratings = Enum.map(sorted, & &1.rating)
      assert ratings == [5.0, 7.0, 9.0]
    end

    test "sorts by author name", %{reviews: reviews} do
      sorted = Reviews.sort_reviews(reviews, :author, :asc)

      authors = Enum.map(sorted, & &1.author)
      assert authors == ["Alice", "Bob", "Charlie"]
    end

    test "handles nil values in sorting" do
      reviews = [
        %Review{id: "1", author: "Alice", rating: 7.0, created_at: nil},
        %Review{id: "2", author: "Bob", rating: nil, created_at: ~U[2023-01-01 00:00:00Z]}
      ]

      # Should not crash with nil values
      sorted_by_date = Reviews.sort_reviews(reviews, :date)
      assert length(sorted_by_date) == 2

      sorted_by_rating = Reviews.sort_reviews(reviews, :rating)
      assert length(sorted_by_rating) == 2
    end
  end

  describe "paginate_reviews/3" do
    setup do
      reviews = Enum.map(1..15, fn i ->
        %Review{id: "#{i}", author: "User#{i}", content: "Review #{i}"}
      end)

      {:ok, reviews: reviews}
    end

    test "paginates reviews correctly", %{reviews: reviews} do
      result = Reviews.paginate_reviews(reviews, 1, 5)

      assert %{reviews: page_reviews, pagination: pagination} = result
      assert length(page_reviews) == 5
      assert pagination.page == 1
      assert pagination.per_page == 5
      assert pagination.total == 15
      assert pagination.total_pages == 3
      assert pagination.has_next == true
      assert pagination.has_prev == false
    end

    test "handles last page correctly", %{reviews: reviews} do
      result = Reviews.paginate_reviews(reviews, 3, 5)

      assert %{reviews: page_reviews, pagination: pagination} = result
      assert length(page_reviews) == 5  # 15 - 10 = 5
      assert pagination.page == 3
      assert pagination.has_next == false
      assert pagination.has_prev == true
    end

    test "handles page beyond total pages", %{reviews: reviews} do
      result = Reviews.paginate_reviews(reviews, 10, 5)

      assert %{reviews: page_reviews, pagination: pagination} = result
      assert length(page_reviews) == 5  # Should return last page
      assert pagination.page == 3  # Adjusted to last valid page
    end

    test "handles empty reviews list" do
      result = Reviews.paginate_reviews([], 1, 5)

      assert %{reviews: [], pagination: pagination} = result
      assert pagination.total == 0
      assert pagination.total_pages == 1
      assert pagination.has_next == false
      assert pagination.has_prev == false
    end

    test "handles single page", %{reviews: reviews} do
      result = Reviews.paginate_reviews(reviews, 1, 20)

      assert %{reviews: page_reviews, pagination: pagination} = result
      assert length(page_reviews) == 15
      assert pagination.total_pages == 1
      assert pagination.has_next == false
      assert pagination.has_prev == false
    end
  end
end
