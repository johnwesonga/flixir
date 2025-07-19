defmodule Flixir.Reviews.ErrorHandlingIntegrationTest do
  use ExUnit.Case, async: true
  import Mock
  alias Flixir.Reviews
  alias Flixir.Reviews.{TMDBClient, Cache, ErrorHandler}

  describe "get_reviews/3 error handling" do
    test "retries on network errors and falls back to cache" do
      # Mock cache to return cached data on fallback
      cached_reviews = [
        %Flixir.Reviews.Review{
          id: "cached_1",
          author: "Cached User",
          content: "Cached review content",
          rating: 8.0,
          created_at: ~U[2024-01-01 12:00:00Z]
        }
      ]

      with_mocks([
        {TMDBClient, [], [
          fetch_reviews: fn _, _, _ -> {:error, %Req.TransportError{reason: :econnrefused}} end
        ]},
        {Cache, [], [
          get_reviews: fn
            _, _, %{} -> {:ok, cached_reviews}  # Return cached data for fallback call
            _, _, _ -> :error  # Return error for initial cache check
          end,
          put_reviews: fn _, _, _, _ -> :ok end
        ]}
      ]) do
        result = Reviews.get_reviews("movie", 123)

        assert {:ok, %{reviews: reviews}} = result
        assert length(reviews) == 1
        assert hd(reviews).id == "cached_1"

        # TMDBClient should be called but cache fallback should work
      end
    end

    test "returns error when retries exhausted and no cache available" do
      with_mocks([
        {TMDBClient, [], [
          fetch_reviews: fn _, _, _ -> {:error, %Req.TransportError{reason: :econnrefused}} end
        ]},
        {Cache, [], [
          get_reviews: fn _, _, _ -> :error end,
          put_reviews: fn _, _, _, _ -> :ok end
        ]}
      ]) do
        result = Reviews.get_reviews("movie", 123)

        assert {:error, :network_error} = result

        # Should have attempted multiple retries
        assert called(TMDBClient.fetch_reviews("movie", 123, 1))
      end
    end

    test "handles rate limiting without retries" do
      with_mocks([
        {TMDBClient, [], [
          fetch_reviews: fn _, _, _ -> {:error, :rate_limited} end
        ]},
        {Cache, [], [
          get_reviews: fn _, _, _ -> :error end
        ]}
      ]) do
        result = Reviews.get_reviews("movie", 123)

        assert {:error, :rate_limited} = result
      end
    end

    test "handles not found errors without fallback" do
      with_mocks([
        {TMDBClient, [], [
          fetch_reviews: fn _, _, _ -> {:error, :not_found} end
        ]},
        {Cache, [], [
          get_reviews: fn _, _, _ -> :error end
        ]}
      ]) do
        result = Reviews.get_reviews("movie", 123)

        assert {:error, :not_found} = result
      end
    end

    test "handles service unavailable with cache fallback" do
      cached_reviews = [
        %Flixir.Reviews.Review{
          id: "fallback_1",
          author: "Fallback User",
          content: "Fallback review",
          rating: 7.5,
          created_at: ~U[2024-01-01 12:00:00Z]
        }
      ]

      with_mocks([
        {TMDBClient, [], [
          fetch_reviews: fn _, _, _ -> {:error, {:unexpected_status, 503}} end
        ]},
        {Cache, [], [
          get_reviews: fn
            _, _, %{} -> {:ok, cached_reviews}
            _, _, _ -> :error
          end
        ]}
      ]) do
        result = Reviews.get_reviews("movie", 123)

        assert {:ok, %{reviews: reviews}} = result
        assert length(reviews) == 1
        assert hd(reviews).id == "fallback_1"
      end
    end
  end

  describe "get_rating_stats/2 error handling" do
    test "retries on network errors and falls back to cache" do
      cached_stats = %Flixir.Reviews.RatingStats{
        average_rating: 7.8,
        total_reviews: 10,
        rating_distribution: %{"8" => 5, "7" => 3, "6" => 2}
      }

      with_mocks([
        {TMDBClient, [], [
          fetch_reviews: fn _, _, _ -> {:error, %Req.TransportError{reason: :timeout}} end
        ]},
        {Cache, [], [
          get_ratings: fn _, _ -> {:ok, cached_stats} end,
          put_ratings: fn _, _, _ -> :ok end
        ]}
      ]) do
        result = Reviews.get_rating_stats("movie", 123)

        assert {:ok, stats} = result
        assert stats.average_rating == 7.8
        assert stats.total_reviews == 10
      end
    end

    test "returns error when no cache available" do
      with_mocks([
        {TMDBClient, [], [
          fetch_reviews: fn _, _, _ -> {:error, {:unexpected_status, 500}} end
        ]},
        {Cache, [], [
          get_ratings: fn _, _ -> :error end
        ]}
      ]) do
        result = Reviews.get_rating_stats("movie", 123)

        assert {:error, :service_unavailable} = result
      end
    end
  end

  describe "error message formatting" do
    test "formats user-friendly error messages" do
      network_msg = ErrorHandler.format_user_error({:error, :network_error})
      assert network_msg =~ "connection issues"

      rate_limit_msg = ErrorHandler.format_user_error({:error, :rate_limited})
      assert rate_limit_msg =~ "Too many requests"

      service_msg = ErrorHandler.format_user_error({:error, :service_unavailable})
      assert service_msg =~ "temporarily unavailable"

      not_found_msg = ErrorHandler.format_user_error({:error, :not_found})
      assert not_found_msg =~ "No reviews found"
    end
  end

  describe "retry logic" do
    test "implements exponential backoff" do
      assert ErrorHandler.retry_delay(1) == 1000
      assert ErrorHandler.retry_delay(2) == 2000
      assert ErrorHandler.retry_delay(3) == 4000
      assert ErrorHandler.retry_delay(4) == 8000
    end

    test "identifies retryable vs non-retryable errors" do
      assert ErrorHandler.retryable?({:error, :network_error}) == true
      assert ErrorHandler.retryable?({:error, :service_unavailable}) == true
      assert ErrorHandler.retryable?({:error, :rate_limited}) == true
      assert ErrorHandler.retryable?({:error, :not_found}) == false
    end
  end

  describe "cache fallback strategy" do
    test "uses cache fallback for appropriate errors" do
      assert ErrorHandler.use_cached_fallback?({:error, :network_error}) == true
      assert ErrorHandler.use_cached_fallback?({:error, :service_unavailable}) == true
      assert ErrorHandler.use_cached_fallback?({:error, :rate_limited}) == true
      assert ErrorHandler.use_cached_fallback?({:error, :not_found}) == false
    end
  end
end
