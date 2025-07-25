defmodule Flixir.Media.TMDBClientTest do
  use ExUnit.Case, async: false
  import Mock

  alias Flixir.Media.TMDBClient

  setup do
    # Ensure we have a valid API key for testing
    original_config = Application.get_env(:flixir, :tmdb)
    test_config = Keyword.put(original_config, :api_key, "test_api_key")
    Application.put_env(:flixir, :tmdb, test_config)

    on_exit(fn ->
      Application.put_env(:flixir, :tmdb, original_config)
    end)

    :ok
  end

  # Sample response data for testing
  @sample_search_response %{
    "page" => 1,
    "results" => [
      %{
        "id" => 550,
        "title" => "Fight Club",
        "media_type" => "movie",
        "release_date" => "1999-10-15",
        "overview" => "A ticking-time-bomb insomniac...",
        "poster_path" => "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        "genre_ids" => [18, 53],
        "vote_average" => 8.4,
        "popularity" => 61.416
      },
      %{
        "id" => 1399,
        "name" => "Game of Thrones",
        "media_type" => "tv",
        "first_air_date" => "2011-04-17",
        "overview" => "Seven noble families fight...",
        "poster_path" => "/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg",
        "genre_ids" => [18, 10765],
        "vote_average" => 8.3,
        "popularity" => 369.594
      }
    ],
    "total_pages" => 1,
    "total_results" => 2
  }

  @sample_movie_details %{
    "id" => 550,
    "title" => "Fight Club",
    "overview" => "A ticking-time-bomb insomniac...",
    "release_date" => "1999-10-15",
    "runtime" => 139,
    "genres" => [%{"id" => 18, "name" => "Drama"}],
    "vote_average" => 8.4,
    "poster_path" => "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg"
  }

  @sample_tv_details %{
    "id" => 1399,
    "name" => "Game of Thrones",
    "overview" => "Seven noble families fight...",
    "first_air_date" => "2011-04-17",
    "number_of_seasons" => 8,
    "genres" => [%{"id" => 18, "name" => "Drama"}],
    "vote_average" => 8.3,
    "poster_path" => "/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg"
  }

  @sample_movie_list_response %{
    "page" => 1,
    "results" => [
      %{
        "id" => 550,
        "title" => "Fight Club",
        "release_date" => "1999-10-15",
        "overview" => "A ticking-time-bomb insomniac...",
        "poster_path" => "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
        "genre_ids" => [18, 53],
        "vote_average" => 8.4,
        "popularity" => 61.416
      },
      %{
        "id" => 680,
        "title" => "Pulp Fiction",
        "release_date" => "1994-10-14",
        "overview" => "A burger-loving hit man...",
        "poster_path" => "/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg",
        "genre_ids" => [80, 18],
        "vote_average" => 8.5,
        "popularity" => 67.954
      }
    ],
    "total_pages" => 500,
    "total_results" => 10000
  }

  describe "search_multi/2" do
    test "returns successful response with valid query" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_search_response}}
        end do
        assert {:ok, response} = TMDBClient.search_multi("fight club")
        assert response == @sample_search_response
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct parameters in API call" do
      with_mock Req,
        get: fn url, opts ->
          # Verify URL and parameters
          assert String.contains?(url, "/search/multi")
          params = opts[:params]
          assert params[:query] == "test query"
          assert params[:page] == 1
          assert params[:api_key] == "test_api_key"

          {:ok, %Req.Response{status: 200, body: @sample_search_response}}
        end do
        TMDBClient.search_multi("test query")
        assert called(Req.get(:_, :_))
      end
    end

    test "handles custom page parameter" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == 3
          {:ok, %Req.Response{status: 200, body: @sample_search_response}}
        end do
        TMDBClient.search_multi("test", 3)
        assert called(Req.get(:_, :_))
      end
    end

    test "includes proper request headers" do
      with_mock Req,
        get: fn _url, opts ->
          headers = opts[:headers]
          assert {"Accept", "application/json"} in headers
          assert {"Content-Type", "application/json"} in headers
          assert {"User-Agent", "Flixir/1.0"} in headers
          {:ok, %Req.Response{status: 200, body: @sample_search_response}}
        end do
        TMDBClient.search_multi("test")
        assert called(Req.get(:_, :_))
      end
    end

    test "includes timeout and retry configuration" do
      with_mock Req,
        get: fn _url, opts ->
          # The setup sets api_key but doesn't override timeout, so it uses default 5000
          # Default timeout
          assert opts[:receive_timeout] == 5_000
          assert opts[:retry] == :transient
          # Default max_retries
          assert opts[:max_retries] == 3
          {:ok, %Req.Response{status: 200, body: @sample_search_response}}
        end do
        TMDBClient.search_multi("test")
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "get_movie_details/1" do
    test "returns successful response with valid movie ID" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_movie_details}}
        end do
        assert {:ok, response} = TMDBClient.get_movie_details(550)
        assert response == @sample_movie_details
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct URL and parameters" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/movie/550")
          params = opts[:params]
          assert params[:api_key] == "test_api_key"
          {:ok, %Req.Response{status: 200, body: @sample_movie_details}}
        end do
        TMDBClient.get_movie_details(550)
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "get_tv_details/1" do
    test "returns successful response with valid TV ID" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_tv_details}}
        end do
        assert {:ok, response} = TMDBClient.get_tv_details(1399)
        assert response == @sample_tv_details
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct URL and parameters" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/tv/1399")
          params = opts[:params]
          assert params[:api_key] == "test_api_key"
          {:ok, %Req.Response{status: 200, body: @sample_tv_details}}
        end do
        TMDBClient.get_tv_details(1399)
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "get_popular_movies/1" do
    test "returns successful response with default page" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        assert {:ok, response} = TMDBClient.get_popular_movies()
        assert response == @sample_movie_list_response
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct URL and parameters with default page" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/movie/popular")
          params = opts[:params]
          assert params[:page] == 1
          assert params[:api_key] == "test_api_key"
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_popular_movies()
        assert called(Req.get(:_, :_))
      end
    end

    test "handles custom page parameter" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == 3
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_popular_movies(3)
        assert called(Req.get(:_, :_))
      end
    end

    test "includes proper request headers and configuration" do
      with_mock Req,
        get: fn _url, opts ->
          headers = opts[:headers]
          assert {"Accept", "application/json"} in headers
          assert {"Content-Type", "application/json"} in headers
          assert {"User-Agent", "Flixir/1.0"} in headers
          assert opts[:receive_timeout] == 5_000
          assert opts[:retry] == :transient
          assert opts[:max_retries] == 3
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_popular_movies()
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "get_trending_movies/2" do
    test "returns successful response with default parameters" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        assert {:ok, response} = TMDBClient.get_trending_movies()
        assert response == @sample_movie_list_response
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct URL and parameters with defaults" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/trending/movie/week")
          params = opts[:params]
          assert params[:page] == 1
          assert params[:api_key] == "test_api_key"
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_trending_movies()
        assert called(Req.get(:_, :_))
      end
    end

    test "handles custom time window parameter" do
      with_mock Req,
        get: fn url, _opts ->
          assert String.contains?(url, "/trending/movie/day")
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_trending_movies("day")
        assert called(Req.get(:_, :_))
      end
    end

    test "handles custom time window and page parameters" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/trending/movie/day")
          params = opts[:params]
          assert params[:page] == 2
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_trending_movies("day", 2)
        assert called(Req.get(:_, :_))
      end
    end

    test "validates time window parameter in URL" do
      with_mock Req,
        get: fn url, _opts ->
          assert String.contains?(url, "/trending/movie/week")
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_trending_movies("week", 1)
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "get_top_rated_movies/1" do
    test "returns successful response with default page" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        assert {:ok, response} = TMDBClient.get_top_rated_movies()
        assert response == @sample_movie_list_response
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct URL and parameters" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/movie/top_rated")
          params = opts[:params]
          assert params[:page] == 1
          assert params[:api_key] == "test_api_key"
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_top_rated_movies()
        assert called(Req.get(:_, :_))
      end
    end

    test "handles custom page parameter" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == 5
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_top_rated_movies(5)
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "get_upcoming_movies/1" do
    test "returns successful response with default page" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        assert {:ok, response} = TMDBClient.get_upcoming_movies()
        assert response == @sample_movie_list_response
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct URL and parameters" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/movie/upcoming")
          params = opts[:params]
          assert params[:page] == 1
          assert params[:api_key] == "test_api_key"
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_upcoming_movies()
        assert called(Req.get(:_, :_))
      end
    end

    test "handles custom page parameter" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == 4
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_upcoming_movies(4)
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "get_now_playing_movies/1" do
    test "returns successful response with default page" do
      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        assert {:ok, response} = TMDBClient.get_now_playing_movies()
        assert response == @sample_movie_list_response
        assert called(Req.get(:_, :_))
      end
    end

    test "includes correct URL and parameters" do
      with_mock Req,
        get: fn url, opts ->
          assert String.contains?(url, "/movie/now_playing")
          params = opts[:params]
          assert params[:page] == 1
          assert params[:api_key] == "test_api_key"
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_now_playing_movies()
        assert called(Req.get(:_, :_))
      end
    end

    test "handles custom page parameter" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == 2
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_now_playing_movies(2)
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "error handling" do
    test "handles 401 unauthorized error" do
      error_body = %{"status_message" => "Invalid API key", "status_code" => 7}

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 401, body: error_body}}
        end do
        assert {:error, {:unauthorized, "Invalid API key", ^error_body}} =
                 TMDBClient.search_multi("test")
      end
    end

    test "handles 429 rate limiting error" do
      error_body = %{"status_message" => "Request count over limit", "status_code" => 25}

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 429, body: error_body}}
        end do
        assert {:error, {:rate_limited, "Too many requests", ^error_body}} =
                 TMDBClient.search_multi("test")
      end
    end

    test "handles other API errors" do
      error_body = %{"status_message" => "Internal error", "status_code" => 11}

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 500, body: error_body}}
        end do
        assert {:error, {:api_error, 500, ^error_body}} =
                 TMDBClient.search_multi("test")
      end
    end

    test "handles timeout errors" do
      with_mock Req,
        get: fn _url, _opts ->
          {:error, %Req.TransportError{reason: :timeout}}
        end do
        assert {:error, {:timeout, "Request timed out"}} =
                 TMDBClient.search_multi("test")
      end
    end

    test "handles general request failures" do
      with_mock Req,
        get: fn _url, _opts ->
          {:error, :some_network_error}
        end do
        assert {:error, {:request_failed, :some_network_error}} =
                 TMDBClient.search_multi("test")
      end
    end

    test "handles connection errors" do
      with_mock Req,
        get: fn _url, _opts ->
          {:error, %Req.TransportError{reason: :econnrefused}}
        end do
        assert {:error, {:request_failed, %Req.TransportError{reason: :econnrefused}}} =
                 TMDBClient.search_multi("test")
      end
    end
  end

  describe "error handling for movie details" do
    test "handles 404 not found for movie" do
      error_body = %{
        "status_message" => "The resource you requested could not be found.",
        "status_code" => 34
      }

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 404, body: error_body}}
        end do
        assert {:error, {:api_error, 404, ^error_body}} =
                 TMDBClient.get_movie_details(999_999)
      end
    end

    test "handles timeout for movie details" do
      with_mock Req,
        get: fn _url, _opts ->
          {:error, %Req.TransportError{reason: :timeout}}
        end do
        assert {:error, {:timeout, "Request timed out"}} =
                 TMDBClient.get_movie_details(550)
      end
    end
  end

  describe "error handling for TV details" do
    test "handles 404 not found for TV show" do
      error_body = %{
        "status_message" => "The resource you requested could not be found.",
        "status_code" => 34
      }

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 404, body: error_body}}
        end do
        assert {:error, {:api_error, 404, ^error_body}} =
                 TMDBClient.get_tv_details(999_999)
      end
    end

    test "handles rate limiting for TV details" do
      error_body = %{"status_message" => "Request count over limit", "status_code" => 25}

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 429, body: error_body}}
        end do
        assert {:error, {:rate_limited, "Too many requests", ^error_body}} =
                 TMDBClient.get_tv_details(1399)
      end
    end
  end

  describe "error handling for movie lists" do
    test "handles 401 unauthorized error for popular movies" do
      error_body = %{"status_message" => "Invalid API key", "status_code" => 7}

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 401, body: error_body}}
        end do
        assert {:error, {:unauthorized, "Invalid API key", ^error_body}} =
                 TMDBClient.get_popular_movies()
      end
    end

    test "handles 429 rate limiting error for trending movies" do
      error_body = %{"status_message" => "Request count over limit", "status_code" => 25}

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 429, body: error_body}}
        end do
        assert {:error, {:rate_limited, "Too many requests", ^error_body}} =
                 TMDBClient.get_trending_movies()
      end
    end

    test "handles timeout errors for top rated movies" do
      with_mock Req,
        get: fn _url, _opts ->
          {:error, %Req.TransportError{reason: :timeout}}
        end do
        assert {:error, {:timeout, "Request timed out"}} =
                 TMDBClient.get_top_rated_movies()
      end
    end

    test "handles 500 server error for upcoming movies" do
      error_body = %{"status_message" => "Internal server error", "status_code" => 11}

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 500, body: error_body}}
        end do
        assert {:error, {:api_error, 500, ^error_body}} =
                 TMDBClient.get_upcoming_movies()
      end
    end

    test "handles connection errors for now playing movies" do
      with_mock Req,
        get: fn _url, _opts ->
          {:error, %Req.TransportError{reason: :econnrefused}}
        end do
        assert {:error, {:request_failed, %Req.TransportError{reason: :econnrefused}}} =
                 TMDBClient.get_now_playing_movies()
      end
    end

    test "handles general request failures for trending movies with custom time window" do
      with_mock Req,
        get: fn _url, _opts ->
          {:error, :network_unreachable}
        end do
        assert {:error, {:request_failed, :network_unreachable}} =
                 TMDBClient.get_trending_movies("day", 2)
      end
    end

    test "handles 404 error for invalid page numbers" do
      error_body = %{
        "status_message" => "The resource you requested could not be found.",
        "status_code" => 34
      }

      with_mock Req,
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 404, body: error_body}}
        end do
        assert {:error, {:api_error, 404, ^error_body}} =
                 TMDBClient.get_popular_movies(999_999)
      end
    end
  end

  describe "parameter validation and edge cases" do
    test "handles zero page number for popular movies" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == 0
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_popular_movies(0)
        assert called(Req.get(:_, :_))
      end
    end

    test "handles negative page number for trending movies" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == -1
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_trending_movies("week", -1)
        assert called(Req.get(:_, :_))
      end
    end

    test "handles large page numbers for top rated movies" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == 1_000_000
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_top_rated_movies(1_000_000)
        assert called(Req.get(:_, :_))
      end
    end

    test "handles empty string time window for trending movies" do
      with_mock Req,
        get: fn url, _opts ->
          assert String.contains?(url, "/trending/movie/")
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_trending_movies("", 1)
        assert called(Req.get(:_, :_))
      end
    end

    test "handles invalid time window for trending movies" do
      with_mock Req,
        get: fn url, _opts ->
          assert String.contains?(url, "/trending/movie/invalid")
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_trending_movies("invalid", 1)
        assert called(Req.get(:_, :_))
      end
    end

    test "handles nil page parameter gracefully" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == nil
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_popular_movies(nil)
        assert called(Req.get(:_, :_))
      end
    end

    test "handles string page parameter" do
      with_mock Req,
        get: fn _url, opts ->
          params = opts[:params]
          assert params[:page] == "5"
          {:ok, %Req.Response{status: 200, body: @sample_movie_list_response}}
        end do
        TMDBClient.get_upcoming_movies("5")
        assert called(Req.get(:_, :_))
      end
    end
  end

  describe "configuration" do
    test "raises error when API key is not configured" do
      original_config = Application.get_env(:flixir, :tmdb)

      try do
        Application.put_env(:flixir, :tmdb, api_key: nil)

        assert_raise RuntimeError, ~r/TMDB API key not configured/, fn ->
          TMDBClient.search_multi("test")
        end
      after
        Application.put_env(:flixir, :tmdb, original_config)
      end
    end

    test "uses configured base URL" do
      original_config = Application.get_env(:flixir, :tmdb)
      custom_config = Keyword.put(original_config, :base_url, "https://custom.api.com/v3")

      try do
        Application.put_env(:flixir, :tmdb, custom_config)

        with_mock Req,
          get: fn url, _opts ->
            assert String.starts_with?(url, "https://custom.api.com/v3")
            {:ok, %Req.Response{status: 200, body: @sample_search_response}}
          end do
          TMDBClient.search_multi("test")
          assert called(Req.get(:_, :_))
        end
      after
        Application.put_env(:flixir, :tmdb, original_config)
      end
    end

    test "uses configured timeout" do
      original_config = Application.get_env(:flixir, :tmdb)
      custom_config = Keyword.put(original_config, :timeout, 2000)

      try do
        Application.put_env(:flixir, :tmdb, custom_config)

        with_mock Req,
          get: fn _url, opts ->
            assert opts[:receive_timeout] == 2000
            {:ok, %Req.Response{status: 200, body: @sample_search_response}}
          end do
          TMDBClient.search_multi("test")
          assert called(Req.get(:_, :_))
        end
      after
        Application.put_env(:flixir, :tmdb, original_config)
      end
    end

    test "uses configured max retries" do
      original_config = Application.get_env(:flixir, :tmdb)
      custom_config = Keyword.put(original_config, :max_retries, 5)

      try do
        Application.put_env(:flixir, :tmdb, custom_config)

        with_mock Req,
          get: fn _url, opts ->
            assert opts[:max_retries] == 5
            {:ok, %Req.Response{status: 200, body: @sample_search_response}}
          end do
          TMDBClient.search_multi("test")
          assert called(Req.get(:_, :_))
        end
      after
        Application.put_env(:flixir, :tmdb, original_config)
      end
    end
  end

  describe "integration tests" do
    @tag :integration
    test "real API call with search_multi (requires API key)" do
      # Skip if no real API key is configured
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        # Temporarily set real API key
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          case TMDBClient.search_multi("fight club") do
            {:ok, response} ->
              assert is_map(response)
              assert Map.has_key?(response, "results")
              assert is_list(response["results"])

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        # Skip test if no API key available
        :ok
      end
    end

    @tag :integration
    test "real API call with get_movie_details (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          # Test with Fight Club movie ID
          case TMDBClient.get_movie_details(550) do
            {:ok, response} ->
              assert is_map(response)
              assert response["id"] == 550
              assert Map.has_key?(response, "title")

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end

    @tag :integration
    test "real API call with get_tv_details (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          # Test with Game of Thrones TV ID
          case TMDBClient.get_tv_details(1399) do
            {:ok, response} ->
              assert is_map(response)
              assert response["id"] == 1399
              assert Map.has_key?(response, "name")

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end

    @tag :integration
    test "real API call with get_popular_movies (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          case TMDBClient.get_popular_movies() do
            {:ok, response} ->
              assert is_map(response)
              assert Map.has_key?(response, "results")
              assert is_list(response["results"])
              assert Map.has_key?(response, "page")
              assert Map.has_key?(response, "total_pages")

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end

    @tag :integration
    test "real API call with get_trending_movies (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          case TMDBClient.get_trending_movies("week") do
            {:ok, response} ->
              assert is_map(response)
              assert Map.has_key?(response, "results")
              assert is_list(response["results"])
              assert Map.has_key?(response, "page")

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end

    @tag :integration
    test "real API call with get_top_rated_movies (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          case TMDBClient.get_top_rated_movies() do
            {:ok, response} ->
              assert is_map(response)
              assert Map.has_key?(response, "results")
              assert is_list(response["results"])
              # Verify movies have ratings
              if length(response["results"]) > 0 do
                first_movie = hd(response["results"])
                assert Map.has_key?(first_movie, "vote_average")
              end

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end

    @tag :integration
    test "real API call with get_upcoming_movies (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          case TMDBClient.get_upcoming_movies() do
            {:ok, response} ->
              assert is_map(response)
              assert Map.has_key?(response, "results")
              assert is_list(response["results"])
              # Verify movies have release dates
              if length(response["results"]) > 0 do
                first_movie = hd(response["results"])
                assert Map.has_key?(first_movie, "release_date")
              end

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end

    @tag :integration
    test "real API call with get_now_playing_movies (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          case TMDBClient.get_now_playing_movies() do
            {:ok, response} ->
              assert is_map(response)
              assert Map.has_key?(response, "results")
              assert is_list(response["results"])
              assert Map.has_key?(response, "page")

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end

    @tag :integration
    test "real API call with get_trending_movies day parameter (requires API key)" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key do
        original_config = Application.get_env(:flixir, :tmdb)
        real_config = Keyword.put(original_config, :api_key, api_key)

        try do
          Application.put_env(:flixir, :tmdb, real_config)

          case TMDBClient.get_trending_movies("day", 1) do
            {:ok, response} ->
              assert is_map(response)
              assert Map.has_key?(response, "results")
              assert is_list(response["results"])

            {:error, reason} ->
              flunk("API call failed: #{inspect(reason)}")
          end
        after
          Application.put_env(:flixir, :tmdb, original_config)
        end
      else
        :ok
      end
    end
  end
end
