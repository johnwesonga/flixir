defmodule Flixir.Reviews.TMDBClientTest do
  use ExUnit.Case, async: true
  import Mock

  alias Flixir.Reviews.TMDBClient
  alias Flixir.Reviews.Review

  # Mock the Application.get_env to return test configuration
  defp mock_config do
    [
      {Application, [:passthrough], [
        get_env: fn
          :flixir, :tmdb -> [
            api_key: "test_api_key",
            timeout: 5_000,
            max_retries: 3
          ]
          app, key -> Application.get_env(app, key)
        end
      ]}
    ]
  end

  describe "fetch_reviews/3" do
    test "successfully fetches reviews for a movie" do
      mock_response = %{
        "results" => [
          %{
            "id" => "review_123",
            "author" => "John Doe",
            "author_details" => %{"rating" => 8.5},
            "content" => "Great movie! Really enjoyed it.",
            "created_at" => "2023-01-01T00:00:00.000Z",
            "updated_at" => "2023-01-01T00:00:00.000Z",
            "url" => "https://example.com/review/123"
          }
        ],
        "total_pages" => 1,
        "total_results" => 1,
        "page" => 1
      }

      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:ok, %Req.Response{status: 200, body: mock_response}} end]}] do
        assert {:ok, result} = TMDBClient.fetch_reviews("movie", 550, 1)

        assert %{
          reviews: [review],
          total_pages: 1,
          total_results: 1,
          page: 1
        } = result

        assert %Review{
          id: "review_123",
          author: "John Doe",
          content: "Great movie! Really enjoyed it.",
          rating: 8.5
        } = review
      end
    end

    test "successfully fetches reviews for a TV show" do
      mock_response = %{
        "results" => [
          %{
            "id" => "tv_review_456",
            "author" => "Jane Smith",
            "author_details" => %{},
            "content" => "Amazing series with great character development.",
            "created_at" => "2023-02-01T00:00:00.000Z",
            "url" => "https://example.com/review/456"
          }
        ],
        "total_pages" => 2,
        "total_results" => 25,
        "page" => 1
      }

      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:ok, %Req.Response{status: 200, body: mock_response}} end]}] do
        assert {:ok, result} = TMDBClient.fetch_reviews("tv", 1399, 1)

        assert %{
          reviews: [review],
          total_pages: 2,
          total_results: 25,
          page: 1
        } = result

        assert %Review{
          id: "tv_review_456",
          author: "Jane Smith",
          content: "Amazing series with great character development.",
          rating: nil
        } = review
      end
    end

    test "handles empty results" do
      mock_response = %{
        "results" => [],
        "total_pages" => 0,
        "total_results" => 0,
        "page" => 1
      }

      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:ok, %Req.Response{status: 200, body: mock_response}} end]}] do
        assert {:ok, result} = TMDBClient.fetch_reviews("movie", 999, 1)

        assert %{
          reviews: [],
          total_pages: 0,
          total_results: 0,
          page: 1
        } = result
      end
    end

    test "returns error for invalid media type" do
      assert {:error, :invalid_media_type} = TMDBClient.fetch_reviews("invalid", 123, 1)
      assert {:error, :invalid_media_type} = TMDBClient.fetch_reviews("book", 123, 1)
    end

    test "returns error for invalid media ID" do
      assert {:error, :invalid_media_id} = TMDBClient.fetch_reviews("movie", 0, 1)
      assert {:error, :invalid_media_id} = TMDBClient.fetch_reviews("movie", -1, 1)
      assert {:error, :invalid_media_id} = TMDBClient.fetch_reviews("movie", "invalid", 1)
    end

    test "returns error for invalid page number" do
      assert {:error, :invalid_page} = TMDBClient.fetch_reviews("movie", 123, 0)
      assert {:error, :invalid_page} = TMDBClient.fetch_reviews("movie", 123, -1)
      assert {:error, :invalid_page} = TMDBClient.fetch_reviews("movie", 123, "invalid")
    end

    test "handles 401 unauthorized response" do
      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:ok, %Req.Response{status: 401, body: %{}}} end]}] do
        assert {:error, :unauthorized} = TMDBClient.fetch_reviews("movie", 550, 1)
      end
    end

    test "handles 404 not found response" do
      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:ok, %Req.Response{status: 404, body: %{}}} end]}] do
        assert {:error, :not_found} = TMDBClient.fetch_reviews("movie", 999999, 1)
      end
    end

    test "handles 429 rate limited response" do
      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:ok, %Req.Response{status: 429, body: %{}}} end]}] do
        assert {:error, :rate_limited} = TMDBClient.fetch_reviews("movie", 550, 1)
      end
    end

    test "handles unexpected status codes" do
      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:ok, %Req.Response{status: 500, body: %{}}} end]}] do
        assert {:error, {:unexpected_status, 500}} = TMDBClient.fetch_reviews("movie", 550, 1)
      end
    end

    test "handles timeout errors" do
      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:error, %Req.TransportError{reason: :timeout}} end]}] do
        assert {:error, :timeout} = TMDBClient.fetch_reviews("movie", 550, 1)
      end
    end

    test "handles transport errors" do
      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:error, %Req.TransportError{reason: :econnrefused}} end]}] do
        assert {:error, {:transport_error, :econnrefused}} = TMDBClient.fetch_reviews("movie", 550, 1)
      end
    end

    test "handles generic request errors" do
      with_mocks mock_config() ++ [{Req, [], [get: fn(_url, _opts) -> {:error, :some_error} end]}] do
        assert {:error, :some_error} = TMDBClient.fetch_reviews("movie", 550, 1)
      end
    end
  end

  describe "parse_reviews_response/1" do
    test "parses valid response with multiple reviews" do
      response = %{
        "results" => [
          %{
            "id" => "review_1",
            "author" => "Reviewer One",
            "author_details" => %{"rating" => 9.0},
            "content" => "Excellent movie!",
            "created_at" => "2023-01-01T00:00:00.000Z",
            "url" => "https://example.com/review/1"
          },
          %{
            "id" => "review_2",
            "author" => "Reviewer Two",
            "author_details" => %{},
            "content" => "Not bad, but could be better.",
            "created_at" => "2023-01-02T00:00:00.000Z"
          }
        ],
        "total_pages" => 3,
        "total_results" => 50,
        "page" => 2
      }

      assert {:ok, result} = TMDBClient.parse_reviews_response(response)

      assert %{
        reviews: reviews,
        total_pages: 3,
        total_results: 50,
        page: 2
      } = result

      assert length(reviews) == 2

      [review1, review2] = reviews
      assert review1.id == "review_1"
      assert review1.rating == 9.0
      assert review2.id == "review_2"
      assert review2.rating == nil
    end

    test "handles response with missing optional fields" do
      response = %{
        "results" => [
          %{
            "id" => "review_minimal",
            "author" => "Minimal Reviewer",
            "content" => "Short review."
          }
        ]
      }

      assert {:ok, result} = TMDBClient.parse_reviews_response(response)

      assert %{
        reviews: [review],
        total_pages: 1,
        total_results: 1,
        page: 1
      } = result

      assert review.id == "review_minimal"
      assert review.author == "Minimal Reviewer"
      assert review.content == "Short review."
      assert review.rating == nil
    end

    test "filters out invalid reviews" do
      response = %{
        "results" => [
          %{
            "id" => "valid_review",
            "author" => "Valid Author",
            "content" => "Valid content"
          },
          %{
            "id" => "invalid_review"
            # Missing required fields
          },
          "invalid_format"
        ],
        "total_pages" => 1,
        "total_results" => 3
      }

      assert {:ok, result} = TMDBClient.parse_reviews_response(response)

      assert %{
        reviews: [review],
        total_pages: 1,
        total_results: 3
      } = result

      assert review.id == "valid_review"
      assert length(result.reviews) == 1
    end

    test "returns error for invalid response format" do
      assert {:error, :invalid_response_format} = TMDBClient.parse_reviews_response(%{})
      assert {:error, :invalid_response_format} = TMDBClient.parse_reviews_response(%{"results" => "not_a_list"})
      assert {:error, :invalid_response_format} = TMDBClient.parse_reviews_response("invalid")
      assert {:error, :invalid_response_format} = TMDBClient.parse_reviews_response(nil)
    end
  end

  describe "build_reviews_url/3" do
    test "builds correct URL for movie reviews" do
      with_mocks mock_config() do
        url = TMDBClient.build_reviews_url("movie", 550, 1)

        assert String.contains?(url, "https://api.themoviedb.org/3/movie/550/reviews")
        assert String.contains?(url, "api_key=test_api_key")
        assert String.contains?(url, "page=1")
      end
    end

    test "builds correct URL for TV show reviews" do
      with_mocks mock_config() do
        url = TMDBClient.build_reviews_url("tv", 1399, 2)

        assert String.contains?(url, "https://api.themoviedb.org/3/tv/1399/reviews")
        assert String.contains?(url, "api_key=test_api_key")
        assert String.contains?(url, "page=2")
      end
    end

    test "handles different page numbers" do
      with_mocks mock_config() do
        url = TMDBClient.build_reviews_url("movie", 123, 5)
        assert String.contains?(url, "page=5")
      end
    end
  end
end
