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

  describe "get_popular_movies/1" do
    test "returns popular movies from API" do
      mock_api_response = %{
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
          }
        ],
        "total_pages" => 5,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_popular_movies()
        assert %SearchResult{} = result
        assert result.title == "Fight Club"
        assert result.media_type == :movie
        assert result.id == 550
        assert called(TMDBClient.get_popular_movies(1))
        assert called(Cache.put("movies:popular:page:1", :_, 900))
      end
    end

    test "returns cached results when available" do
      cached_results = %{
        results: [
          %SearchResult{
            id: 550,
            title: "Cached Movie",
            media_type: :movie,
            release_date: ~D[1999-10-15],
            overview: "A cached movie...",
            poster_path: "/cached.jpg",
            genre_ids: [18, 53],
            vote_average: 8.4,
            popularity: 61.416
          }
        ],
        has_more: true
      }

      with_mocks([
        {Cache, [], [
          get: fn "movies:popular:page:1" -> {:ok, cached_results} end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_popular_movies()
        assert result.title == "Cached Movie"
        refute called(TMDBClient.get_popular_movies(:_))
      end
    end

    test "supports return_format: :map" do
      mock_api_response = %{
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
          }
        ],
        "total_pages" => 5,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, %{results: [result], has_more: true}} = Media.get_popular_movies(return_format: :map)
        assert %SearchResult{} = result
        assert result.title == "Fight Club"
        assert result.media_type == :movie
      end
    end

    test "supports pagination" do
      mock_api_response = %{
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
          }
        ],
        "total_pages" => 5,
        "page" => 2
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn page -> {:ok, Map.put(mock_api_response, "page", page)} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_popular_movies(page: 2)
        assert %SearchResult{} = result
        assert called(TMDBClient.get_popular_movies(2))
        assert called(Cache.put("movies:popular:page:2", :_, 900))
      end
    end

    test "handles API timeout errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:error, {:timeout, "Request timed out"}} end
        ]}
      ]) do
        assert {:error, {:timeout, message}} = Media.get_popular_movies()
        assert message == "Search request timed out. Please try again."
      end
    end

    test "handles API rate limiting errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:error, {:rate_limited, "Too many requests", %{}}} end
        ]}
      ]) do
        assert {:error, {:rate_limited, message}} = Media.get_popular_movies()
        assert message == "Too many requests. Please wait a moment and try again."
      end
    end

    test "handles API authentication errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:error, {:unauthorized, "Invalid API key", %{}}} end
        ]}
      ]) do
        assert {:error, {:unauthorized, message}} = Media.get_popular_movies()
        assert message == "API authentication failed. Please check configuration."
      end
    end

    test "handles network errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:error, {:request_failed, :econnrefused}} end
        ]}
      ]) do
        assert {:error, {:network_error, message}} = Media.get_popular_movies()
        assert message == "Network error occurred. Please check your connection and try again."
      end
    end

    test "handles invalid API response format" do
      invalid_response = %{"invalid" => "response"}

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, invalid_response} end
        ]}
      ]) do
        assert {:error, {:transformation_error, _reason}} = Media.get_popular_movies()
      end
    end

    test "handles malformed movie data in API response" do
      malformed_response = %{
        "results" => [
          %{"id" => 550},  # Missing required fields
          %{"title" => "Movie"}  # Missing ID
        ],
        "total_pages" => 1,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, malformed_response} end
        ]}
      ]) do
        assert {:error, {:transformation_error, _reason}} = Media.get_popular_movies()
      end
    end

    test "handles response without pagination info" do
      response_without_pagination = %{
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
          }
        ]
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, response_without_pagination} end
        ]}
      ]) do
        assert {:ok, %{results: [result], has_more: false}} = Media.get_popular_movies(return_format: :map)
        assert %SearchResult{} = result
        assert result.title == "Fight Club"
      end
    end

    test "handles empty results" do
      empty_response = %{
        "results" => [],
        "total_pages" => 0,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, empty_response} end
        ]}
      ]) do
        assert {:ok, []} = Media.get_popular_movies()
      end
    end
  end

  describe "get_trending_movies/1" do
    test "returns trending movies from API with default time window" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 123,
            "title" => "Trending Movie",
            "release_date" => "2023-01-15",
            "overview" => "A trending movie...",
            "poster_path" => "/trending.jpg",
            "genre_ids" => [28, 12],
            "vote_average" => 7.5,
            "popularity" => 85.2
          }
        ],
        "total_pages" => 3,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_trending_movies: fn _time_window, _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_trending_movies()
        assert %SearchResult{} = result
        assert result.title == "Trending Movie"
        assert result.media_type == :movie
        assert result.id == 123
        assert called(TMDBClient.get_trending_movies("week", 1))
        assert called(Cache.put("movies:trending:week:page:1", :_, 900))
      end
    end

    test "supports custom time window" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 123,
            "title" => "Daily Trending Movie",
            "release_date" => "2023-01-15",
            "overview" => "A daily trending movie...",
            "poster_path" => "/trending.jpg",
            "genre_ids" => [28, 12],
            "vote_average" => 7.5,
            "popularity" => 85.2
          }
        ],
        "total_pages" => 3,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_trending_movies: fn _time_window, _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_trending_movies(time_window: "day")
        assert %SearchResult{} = result
        assert result.title == "Daily Trending Movie"
        assert called(TMDBClient.get_trending_movies("day", 1))
        assert called(Cache.put("movies:trending:day:page:1", :_, 900))
      end
    end

    test "returns cached results when available" do
      cached_results = %{
        results: [
          %SearchResult{
            id: 123,
            title: "Cached Trending Movie",
            media_type: :movie,
            release_date: ~D[2023-01-15],
            overview: "A cached trending movie...",
            poster_path: "/cached_trending.jpg",
            genre_ids: [28, 12],
            vote_average: 7.5,
            popularity: 85.2
          }
        ],
        has_more: true
      }

      with_mocks([
        {Cache, [], [
          get: fn "movies:trending:week:page:1" -> {:ok, cached_results} end
        ]},
        {TMDBClient, [], [
          get_trending_movies: fn _time_window, _page -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_trending_movies()
        assert result.title == "Cached Trending Movie"
        refute called(TMDBClient.get_trending_movies(:_, :_))
      end
    end

    test "supports return_format: :map" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 123,
            "title" => "Trending Movie",
            "release_date" => "2023-01-15",
            "overview" => "A trending movie...",
            "poster_path" => "/trending.jpg",
            "genre_ids" => [28, 12],
            "vote_average" => 7.5,
            "popularity" => 85.2
          }
        ],
        "total_pages" => 3,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_trending_movies: fn _time_window, _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, %{results: [result], has_more: true}} = Media.get_trending_movies(return_format: :map)
        assert %SearchResult{} = result
        assert result.title == "Trending Movie"
      end
    end

    test "supports pagination" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 123,
            "title" => "Trending Movie Page 2",
            "release_date" => "2023-01-15",
            "overview" => "A trending movie...",
            "poster_path" => "/trending.jpg",
            "genre_ids" => [28, 12],
            "vote_average" => 7.5,
            "popularity" => 85.2
          }
        ],
        "total_pages" => 3,
        "page" => 2
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_trending_movies: fn _time_window, page -> {:ok, Map.put(mock_api_response, "page", page)} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_trending_movies(time_window: "day", page: 2)
        assert %SearchResult{} = result
        assert called(TMDBClient.get_trending_movies("day", 2))
        assert called(Cache.put("movies:trending:day:page:2", :_, 900))
      end
    end

    test "handles API errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_trending_movies: fn _time_window, _page -> {:error, {:api_error, 500, %{"status_message" => "Internal error"}}} end
        ]}
      ]) do
        assert {:error, {:api_error, message}} = Media.get_trending_movies()
        assert message == "Search service temporarily unavailable. Please try again later."
      end
    end
  end

  describe "get_top_rated_movies/1" do
    test "returns top rated movies from API" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 456,
            "title" => "Top Rated Movie",
            "release_date" => "2020-05-10",
            "overview" => "A highly rated movie...",
            "poster_path" => "/toprated.jpg",
            "genre_ids" => [18],
            "vote_average" => 9.1,
            "popularity" => 45.8
          }
        ],
        "total_pages" => 10,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_top_rated_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_top_rated_movies()
        assert %SearchResult{} = result
        assert result.title == "Top Rated Movie"
        assert result.media_type == :movie
        assert result.vote_average == 9.1
        assert called(TMDBClient.get_top_rated_movies(1))
        assert called(Cache.put("movies:top_rated:page:1", :_, 900))
      end
    end

    test "returns cached results when available" do
      cached_results = %{
        results: [
          %SearchResult{
            id: 456,
            title: "Cached Top Rated Movie",
            media_type: :movie,
            release_date: ~D[2020-05-10],
            overview: "A cached highly rated movie...",
            poster_path: "/cached_toprated.jpg",
            genre_ids: [18],
            vote_average: 9.1,
            popularity: 45.8
          }
        ],
        has_more: false
      }

      with_mocks([
        {Cache, [], [
          get: fn "movies:top_rated:page:1" -> {:ok, cached_results} end
        ]},
        {TMDBClient, [], [
          get_top_rated_movies: fn _page -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_top_rated_movies()
        assert result.title == "Cached Top Rated Movie"
        refute called(TMDBClient.get_top_rated_movies(:_))
      end
    end

    test "supports return_format: :map" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 456,
            "title" => "Top Rated Movie",
            "release_date" => "2020-05-10",
            "overview" => "A highly rated movie...",
            "poster_path" => "/toprated.jpg",
            "genre_ids" => [18],
            "vote_average" => 9.1,
            "popularity" => 45.8
          }
        ],
        "total_pages" => 10,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_top_rated_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, %{results: [result], has_more: true}} = Media.get_top_rated_movies(return_format: :map)
        assert %SearchResult{} = result
        assert result.vote_average == 9.1
      end
    end

    test "supports pagination" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 456,
            "title" => "Top Rated Movie Page 3",
            "release_date" => "2020-05-10",
            "overview" => "A highly rated movie...",
            "poster_path" => "/toprated.jpg",
            "genre_ids" => [18],
            "vote_average" => 9.1,
            "popularity" => 45.8
          }
        ],
        "total_pages" => 10,
        "page" => 3
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_top_rated_movies: fn page -> {:ok, Map.put(mock_api_response, "page", page)} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_top_rated_movies(page: 3)
        assert %SearchResult{} = result
        assert called(TMDBClient.get_top_rated_movies(3))
        assert called(Cache.put("movies:top_rated:page:3", :_, 900))
      end
    end

    test "handles API errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_top_rated_movies: fn _page -> {:error, {:timeout, "Request timed out"}} end
        ]}
      ]) do
        assert {:error, {:timeout, message}} = Media.get_top_rated_movies()
        assert message == "Search request timed out. Please try again."
      end
    end
  end

  describe "get_upcoming_movies/1" do
    test "returns upcoming movies from API" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 789,
            "title" => "Upcoming Movie",
            "release_date" => "2024-12-25",
            "overview" => "An upcoming movie...",
            "poster_path" => "/upcoming.jpg",
            "genre_ids" => [28, 878],
            "vote_average" => 0.0,
            "popularity" => 120.5
          }
        ],
        "total_pages" => 2,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_upcoming_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_upcoming_movies()
        assert %SearchResult{} = result
        assert result.title == "Upcoming Movie"
        assert result.media_type == :movie
        assert result.release_date == ~D[2024-12-25]
        assert called(TMDBClient.get_upcoming_movies(1))
        assert called(Cache.put("movies:upcoming:page:1", :_, 900))
      end
    end

    test "returns cached results when available" do
      cached_results = %{
        results: [
          %SearchResult{
            id: 789,
            title: "Cached Upcoming Movie",
            media_type: :movie,
            release_date: ~D[2024-12-25],
            overview: "A cached upcoming movie...",
            poster_path: "/cached_upcoming.jpg",
            genre_ids: [28, 878],
            vote_average: 0.0,
            popularity: 120.5
          }
        ],
        has_more: true
      }

      with_mocks([
        {Cache, [], [
          get: fn "movies:upcoming:page:1" -> {:ok, cached_results} end
        ]},
        {TMDBClient, [], [
          get_upcoming_movies: fn _page -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_upcoming_movies()
        assert result.title == "Cached Upcoming Movie"
        refute called(TMDBClient.get_upcoming_movies(:_))
      end
    end

    test "supports return_format: :map" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 789,
            "title" => "Upcoming Movie",
            "release_date" => "2024-12-25",
            "overview" => "An upcoming movie...",
            "poster_path" => "/upcoming.jpg",
            "genre_ids" => [28, 878],
            "vote_average" => 0.0,
            "popularity" => 120.5
          }
        ],
        "total_pages" => 2,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_upcoming_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, %{results: [result], has_more: true}} = Media.get_upcoming_movies(return_format: :map)
        assert %SearchResult{} = result
        assert result.release_date == ~D[2024-12-25]
      end
    end

    test "supports pagination" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 789,
            "title" => "Upcoming Movie Page 2",
            "release_date" => "2024-12-25",
            "overview" => "An upcoming movie...",
            "poster_path" => "/upcoming.jpg",
            "genre_ids" => [28, 878],
            "vote_average" => 0.0,
            "popularity" => 120.5
          }
        ],
        "total_pages" => 2,
        "page" => 2
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_upcoming_movies: fn page -> {:ok, Map.put(mock_api_response, "page", page)} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_upcoming_movies(page: 2)
        assert %SearchResult{} = result
        assert called(TMDBClient.get_upcoming_movies(2))
        assert called(Cache.put("movies:upcoming:page:2", :_, 900))
      end
    end

    test "handles API errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_upcoming_movies: fn _page -> {:error, {:unauthorized, "Invalid API key", %{}}} end
        ]}
      ]) do
        assert {:error, {:unauthorized, message}} = Media.get_upcoming_movies()
        assert message == "API authentication failed. Please check configuration."
      end
    end
  end

  describe "get_now_playing_movies/1" do
    test "returns now playing movies from API" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 101,
            "title" => "Now Playing Movie",
            "release_date" => "2023-11-01",
            "overview" => "A movie now playing...",
            "poster_path" => "/nowplaying.jpg",
            "genre_ids" => [35, 10749],
            "vote_average" => 6.8,
            "popularity" => 75.3
          }
        ],
        "total_pages" => 4,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_now_playing_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_now_playing_movies()
        assert %SearchResult{} = result
        assert result.title == "Now Playing Movie"
        assert result.media_type == :movie
        assert result.id == 101
        assert called(TMDBClient.get_now_playing_movies(1))
        assert called(Cache.put("movies:now_playing:page:1", :_, 900))
      end
    end

    test "returns cached results when available" do
      cached_results = %{
        results: [
          %SearchResult{
            id: 101,
            title: "Cached Now Playing Movie",
            media_type: :movie,
            release_date: ~D[2023-11-01],
            overview: "A cached movie now playing...",
            poster_path: "/cached_nowplaying.jpg",
            genre_ids: [35, 10749],
            vote_average: 6.8,
            popularity: 75.3
          }
        ],
        has_more: false
      }

      with_mocks([
        {Cache, [], [
          get: fn "movies:now_playing:page:1" -> {:ok, cached_results} end
        ]},
        {TMDBClient, [], [
          get_now_playing_movies: fn _page -> {:ok, %{}} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_now_playing_movies()
        assert result.title == "Cached Now Playing Movie"
        refute called(TMDBClient.get_now_playing_movies(:_))
      end
    end

    test "supports return_format: :map" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 101,
            "title" => "Now Playing Movie",
            "release_date" => "2023-11-01",
            "overview" => "A movie now playing...",
            "poster_path" => "/nowplaying.jpg",
            "genre_ids" => [35, 10749],
            "vote_average" => 6.8,
            "popularity" => 75.3
          }
        ],
        "total_pages" => 4,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_now_playing_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, %{results: [result], has_more: true}} = Media.get_now_playing_movies(return_format: :map)
        assert %SearchResult{} = result
        assert result.id == 101
      end
    end

    test "supports pagination" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 101,
            "title" => "Now Playing Movie Page 4",
            "release_date" => "2023-11-01",
            "overview" => "A movie now playing...",
            "poster_path" => "/nowplaying.jpg",
            "genre_ids" => [35, 10749],
            "vote_average" => 6.8,
            "popularity" => 75.3
          }
        ],
        "total_pages" => 4,
        "page" => 4
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_now_playing_movies: fn page -> {:ok, Map.put(mock_api_response, "page", page)} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_now_playing_movies(page: 4)
        assert %SearchResult{} = result
        assert called(TMDBClient.get_now_playing_movies(4))
        assert called(Cache.put("movies:now_playing:page:4", :_, 900))
      end
    end

    test "handles API errors" do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end
        ]},
        {TMDBClient, [], [
          get_now_playing_movies: fn _page -> {:error, {:request_failed, :econnrefused}} end
        ]}
      ]) do
        assert {:error, {:network_error, message}} = Media.get_now_playing_movies()
        assert message == "Network error occurred. Please check your connection and try again."
      end
    end
  end

  describe "movie list caching behavior" do
    test "uses correct cache keys for different list types" do
      with_mocks([
        {Cache, [], [
          get: fn key ->
            case key do
              "movies:popular:page:1" -> :error
              "movies:trending:week:page:1" -> :error
              "movies:top_rated:page:1" -> :error
              "movies:upcoming:page:1" -> :error
              "movies:now_playing:page:1" -> :error
            end
          end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, %{"results" => [], "total_pages" => 1, "page" => 1}} end,
          get_trending_movies: fn _time_window, _page -> {:ok, %{"results" => [], "total_pages" => 1, "page" => 1}} end,
          get_top_rated_movies: fn _page -> {:ok, %{"results" => [], "total_pages" => 1, "page" => 1}} end,
          get_upcoming_movies: fn _page -> {:ok, %{"results" => [], "total_pages" => 1, "page" => 1}} end,
          get_now_playing_movies: fn _page -> {:ok, %{"results" => [], "total_pages" => 1, "page" => 1}} end
        ]}
      ]) do
        Media.get_popular_movies()
        Media.get_trending_movies()
        Media.get_top_rated_movies()
        Media.get_upcoming_movies()
        Media.get_now_playing_movies()

        assert called(Cache.get("movies:popular:page:1"))
        assert called(Cache.get("movies:trending:week:page:1"))
        assert called(Cache.get("movies:top_rated:page:1"))
        assert called(Cache.get("movies:upcoming:page:1"))
        assert called(Cache.get("movies:now_playing:page:1"))
      end
    end

    test "caches results with 15-minute TTL (900 seconds)" do
      mock_api_response = %{
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
          }
        ],
        "total_pages" => 5,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, ttl ->
            assert ttl == 900
            :ok
          end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        Media.get_popular_movies()
        assert called(Cache.put("movies:popular:page:1", :_, 900))
      end
    end

    test "handles cache format conversion between :list and :map formats" do
      # Test cached results in map format being returned as list format
      cached_map_results = %{
        results: [
          %SearchResult{
            id: 550,
            title: "Cached Movie",
            media_type: :movie,
            release_date: ~D[1999-10-15],
            overview: "A cached movie...",
            poster_path: "/cached.jpg",
            genre_ids: [18, 53],
            vote_average: 8.4,
            popularity: 61.416
          }
        ],
        has_more: true
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> {:ok, cached_map_results} end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, %{}} end
        ]}
      ]) do
        # Request list format (default)
        assert {:ok, [result]} = Media.get_popular_movies()
        assert result.title == "Cached Movie"

        # Request map format
        assert {:ok, %{results: [result], has_more: true}} = Media.get_popular_movies(return_format: :map)
        assert result.title == "Cached Movie"
      end
    end

    test "handles legacy cached results in list format" do
      # Test cached results in legacy list format
      cached_list_results = [
        %SearchResult{
          id: 550,
          title: "Legacy Cached Movie",
          media_type: :movie,
          release_date: ~D[1999-10-15],
          overview: "A legacy cached movie...",
          poster_path: "/legacy_cached.jpg",
          genre_ids: [18, 53],
          vote_average: 8.4,
          popularity: 61.416
        }
      ]

      with_mocks([
        {Cache, [], [
          get: fn _key -> {:ok, cached_list_results} end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, %{}} end
        ]}
      ]) do
        # Request list format (default)
        assert {:ok, [result]} = Media.get_popular_movies()
        assert result.title == "Legacy Cached Movie"

        # Request map format - with legacy list format cached results,
        # the function returns the cached list directly without conversion
        assert {:ok, [result]} = Media.get_popular_movies(return_format: :map)
        assert result.title == "Legacy Cached Movie"
      end
    end
  end

  describe "movie list pagination logic" do
    test "correctly determines has_more based on total_pages" do
      # Test when current page is less than total pages
      response_with_more = %{
        "results" => [
          %{
            "id" => 550,
            "title" => "Movie 1",
            "release_date" => "1999-10-15",
            "overview" => "Movie overview...",
            "poster_path" => "/movie.jpg",
            "genre_ids" => [18],
            "vote_average" => 8.4,
            "popularity" => 61.416
          }
        ],
        "total_pages" => 5,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, response_with_more} end
        ]}
      ]) do
        assert {:ok, %{results: [_result], has_more: true}} = Media.get_popular_movies(return_format: :map)
      end

      # Test when current page equals total pages
      response_no_more = %{
        "results" => [
          %{
            "id" => 550,
            "title" => "Movie 1",
            "release_date" => "1999-10-15",
            "overview" => "Movie overview...",
            "poster_path" => "/movie.jpg",
            "genre_ids" => [18],
            "vote_average" => 8.4,
            "popularity" => 61.416
          }
        ],
        "total_pages" => 1,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, response_no_more} end
        ]}
      ]) do
        assert {:ok, %{results: [_result], has_more: false}} = Media.get_popular_movies(return_format: :map)
      end
    end

    test "handles responses with 20 or more results for has_more estimation" do
      # Create 20 results to test the fallback logic
      twenty_results = Enum.map(1..20, fn i ->
        %{
          "id" => i,
          "title" => "Movie #{i}",
          "release_date" => "1999-10-15",
          "overview" => "Movie overview...",
          "poster_path" => "/movie#{i}.jpg",
          "genre_ids" => [18],
          "vote_average" => 8.4,
          "popularity" => 61.416
        }
      end)

      response_without_pagination = %{
        "results" => twenty_results
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, response_without_pagination} end
        ]}
      ]) do
        assert {:ok, %{results: results, has_more: true}} = Media.get_popular_movies(return_format: :map)
        assert length(results) == 20
      end
    end
  end

  describe "movie list result transformation" do
    test "ensures all movie list results have media_type set to :movie" do
      # Test that movie data without explicit media_type gets set to :movie
      mock_api_response = %{
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
            # Note: no "media_type" field in original data
          }
        ],
        "total_pages" => 5,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_popular_movies()
        assert %SearchResult{} = result
        assert result.media_type == :movie
      end
    end

    test "handles movies with missing optional fields" do
      mock_api_response = %{
        "results" => [
          %{
            "id" => 550,
            "title" => "Minimal Movie Data"
            # Missing: release_date, overview, poster_path, genre_ids, vote_average, popularity
          }
        ],
        "total_pages" => 1,
        "page" => 1
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end
        ]},
        {TMDBClient, [], [
          get_popular_movies: fn _page -> {:ok, mock_api_response} end
        ]}
      ]) do
        assert {:ok, [result]} = Media.get_popular_movies()
        assert %SearchResult{} = result
        assert result.title == "Minimal Movie Data"
        assert result.media_type == :movie
        assert result.release_date == nil
        assert result.overview == nil
        assert result.poster_path == nil
        assert result.genre_ids == []
        assert result.vote_average == 0.0
        assert result.popularity == 0.0
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
