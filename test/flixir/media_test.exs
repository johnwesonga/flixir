defmodule Flixir.MediaTest do
  use ExUnit.Case, async: true

  import Mock

  alias Flixir.Media
  alias Flixir.Media.{TMDBClient, Cache, SearchResult}

  describe "search_content/2" do
    test "returns search results for valid query" do
      mock_api_response = %{
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
          }
        ]
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.search_content("fight club")
        assert %SearchResult{} = result
        assert result.title == "Fight Club"
        assert result.media_type == :movie
        assert result.id == 550
      end
    end

    test "returns cached results when available" do
      cached_results = [
        %SearchResult{
          id: 550,
          title: "Fight Club",
          media_type: :movie,
          release_date: ~D[1999-10-15],
          overview: "A ticking-time-bomb insomniac...",
          poster_path: "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
          genre_ids: [18, 53],
          vote_average: 8.4,
          popularity: 61.416
        }
      ]

      with_mocks([
        {Cache, [], [
          get: fn _key -> {:ok, cached_results} end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, results} = Media.search_content("fight club")
        assert results == cached_results
      end
    end

    test "filters results by media type" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 550,
            "title" => "Fight Club",
            "media_type" => "movie",
            "release_date" => "1999-10-15",
            "overview" => "Movie overview",
            "poster_path" => "/movie.jpg",
            "genre_ids" => [18],
            "vote_average" => 8.4,
            "popularity" => 61.416
          },
          %{
            "id" => 1399,
            "name" => "Game of Thrones",
            "media_type" => "tv",
            "first_air_date" => "2011-04-17",
            "overview" => "TV show overview",
            "poster_path" => "/tv.jpg",
            "genre_ids" => [18, 10759],
            "vote_average" => 9.2,
            "popularity" => 369.594
          }
        ]
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        # Test filtering for movies only
        assert {:ok, results} = Media.search_content("test", media_type: :movie)
        assert length(results) == 1
        assert hd(results).media_type == :movie
        assert hd(results).title == "Fight Club"

        # Test filtering for TV shows only
        assert {:ok, results} = Media.search_content("test", media_type: :tv)
        assert length(results) == 1
        assert hd(results).media_type == :tv
        assert hd(results).title == "Game of Thrones"

        # Test no filtering (all types)
        assert {:ok, results} = Media.search_content("test", media_type: :all)
        assert length(results) == 2
      end
    end

    test "sorts results by different criteria" do
      results = [
        %SearchResult{
          id: 1,
          title: "Z Movie",
          media_type: :movie,
          release_date: ~D[2020-01-01],
          popularity: 10.0,
          vote_average: 7.0,
          overview: nil,
          poster_path: nil,
          genre_ids: []
        },
        %SearchResult{
          id: 2,
          title: "A Movie",
          media_type: :movie,
          release_date: ~D[2021-01-01],
          popularity: 20.0,
          vote_average: 8.0,
          overview: nil,
          poster_path: nil,
          genre_ids: []
        }
      ]

      with_mocks([
        {Cache, [], [
          get: fn _key -> {:ok, results} end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, %{}} end
        ]}
      ]) do
        # Test sorting by title (alphabetical)
        assert {:ok, sorted_results} = Media.search_content("test", sort_by: :title)
        assert hd(sorted_results).title == "A Movie"

        # Test sorting by popularity (descending)
        assert {:ok, sorted_results} = Media.search_content("test", sort_by: :popularity)
        assert hd(sorted_results).popularity == 20.0

        # Test sorting by release date (descending)
        assert {:ok, sorted_results} = Media.search_content("test", sort_by: :release_date)
        assert hd(sorted_results).release_date == ~D[2021-01-01]
      end
    end

    test "handles empty search query" do
      assert {:error, "Search query cannot be empty"} = Media.search_content("")
      assert {:error, "Search query cannot be empty"} = Media.search_content("   ")
    end

    test "handles invalid search parameters" do
      assert {:error, _reason} = Media.search_content("test", media_type: :invalid)
      assert {:error, _reason} = Media.search_content("test", sort_by: :invalid)
      assert {:error, _reason} = Media.search_content("test", page: 0)
    end

    test "handles API timeout errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:error, {:timeout, "Request timed out"}} end
        ]}
      ]) do
        assert {:error, {:timeout, message}} = Media.search_content("test")
        assert message == "Search request timed out. Please try again."
      end
    end

    test "handles API rate limiting errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:error, {:rate_limited, "Too many requests", %{}}} end
        ]}
      ]) do
        assert {:error, {:rate_limited, message}} = Media.search_content("test")
        assert message == "Too many requests. Please wait a moment and try again."
      end
    end

    test "handles API authentication errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:error, {:unauthorized, "Invalid API key", %{}}} end
        ]}
      ]) do
        assert {:error, {:unauthorized, message}} = Media.search_content("test")
        assert message == "API authentication failed. Please check configuration."
      end
    end

    test "handles network errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:error, {:request_failed, :econnrefused}} end
        ]}
      ]) do
        assert {:error, {:network_error, message}} = Media.search_content("test")
        assert message == "Network error occurred. Please check your connection and try again."
      end
    end

    test "handles invalid API response format" do
      invalid_response = %{"invalid" => "response"}

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, invalid_response} end
        ]}
      ]) do
        assert {:error, {:transformation_error, _reason}} = Media.search_content("test")
      end
    end
  end

  describe "get_content_details/2" do
    test "returns movie details from API" do
      movie_details = %{
        "id" => 550,
        "title" => "Fight Club",
        "overview" => "A ticking-time-bomb insomniac...",
        "release_date" => "1999-10-15"
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_movie_details: fn _id -> {:ok, movie_details} end
        ]}
      ]) do
        assert {:ok, details} = Media.get_content_details(550, :movie)
        assert details == movie_details
        assert called(TMDBClient.get_movie_details(550))
      end
    end

    test "returns TV show details from API" do
      tv_details = %{
        "id" => 1399,
        "name" => "Game of Thrones",
        "overview" => "Seven noble families fight...",
        "first_air_date" => "2011-04-17"
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_tv_details: fn _id -> {:ok, tv_details} end
        ]}
      ]) do
        assert {:ok, details} = Media.get_content_details(1399, :tv)
        assert details == tv_details
        assert called(TMDBClient.get_tv_details(1399))
      end
    end

    test "returns cached details when available" do
      cached_details = %{"id" => 550, "title" => "Fight Club"}

      with_mocks([
        {Cache, [], [
          get: fn _key -> {:ok, cached_details} end
        ]},
        {TMDBClient, [], [
          get_movie_details: fn _id -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, details} = Media.get_content_details(550, :movie)
        assert details == cached_details
      end
    end

    test "validates content type parameter" do
      assert {:error, "Invalid content type. Must be :movie or :tv"} =
        Media.get_content_details(550, :invalid)
    end

    test "validates content ID parameter" do
      assert {:error, "Invalid content ID. Must be an integer"} =
        Media.get_content_details("550", :movie)

      assert {:error, "Invalid content ID. Must be an integer"} =
        Media.get_content_details(nil, :movie)
    end

    test "handles API errors for content details" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_movie_details: fn _id -> {:error, {:api_error, 404, %{"status_message" => "Not found"}}} end
        ]}
      ]) do
        assert {:error, {:api_error, message}} = Media.get_content_details(999999, :movie)
        assert message == "Search service temporarily unavailable. Please try again later."
      end
    end
  end

  describe "clear_search_cache/0" do
    test "clears the cache successfully" do
      with_mock Cache, [clear: fn -> :ok end] do
        assert :ok = Media.clear_search_cache()
        assert called(Cache.clear())
      end
    end
  end

  describe "cache_stats/0" do
    test "returns cache statistics" do
      mock_stats = %{
        hits: 10,
        misses: 5,
        size: 100,
        memory_bytes: 1024
      }

      with_mock Cache, [stats: fn -> mock_stats end] do
        assert Media.cache_stats() == mock_stats
        assert called(Cache.stats())
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed search results from API" do
      malformed_response = %{
        "results" => [
          %{"id" => 550},  # Missing required fields
          %{"media_type" => "movie"}  # Missing ID
        ]
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, malformed_response} end
        ]}
      ]) do
        assert {:error, {:transformation_error, _reason}} = Media.search_content("test")
      end
    end

    test "handles results with missing release dates in sorting" do
      results = [
        %SearchResult{
          id: 1,
          title: "Movie with Date",
          media_type: :movie,
          release_date: ~D[2020-01-01],
          popularity: 10.0,
          vote_average: 7.0,
          overview: nil,
          poster_path: nil,
          genre_ids: []
        },
        %SearchResult{
          id: 2,
          title: "Movie without Date",
          media_type: :movie,
          release_date: nil,
          popularity: 20.0,
          vote_average: 8.0,
          overview: nil,
          poster_path: nil,
          genre_ids: []
        }
      ]

      with_mocks([
        {Cache, [], [
          get: fn _key -> {:ok, results} end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, sorted_results} = Media.search_content("test", sort_by: :release_date)
        # Movie without date should come first (sorted to beginning with default date)
        assert length(sorted_results) == 2
        assert Enum.at(sorted_results, 0).title == "Movie with Date"
        assert Enum.at(sorted_results, 1).title == "Movie without Date"
      end
    end

    test "handles empty API results" do
      empty_response = %{"results" => []}

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, empty_response} end
        ]}
      ]) do
        assert {:ok, []} = Media.search_content("nonexistent")
      end
    end
  end
end
