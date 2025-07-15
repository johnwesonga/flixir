defmodule Flixir.Media.SearchResultTest do
  use ExUnit.Case, async: true

  alias Flixir.Media.SearchResult

  describe "from_tmdb_data/1" do
    test "creates SearchResult from valid movie data" do
      movie_data = %{
        "id" => 123,
        "title" => "Test Movie",
        "media_type" => "movie",
        "release_date" => "2023-01-15",
        "overview" => "A test movie overview",
        "poster_path" => "/test_poster.jpg",
        "genre_ids" => [28, 12],
        "vote_average" => 7.5,
        "popularity" => 85.2
      }

      assert {:ok, result} = SearchResult.from_tmdb_data(movie_data)
      assert result.id == 123
      assert result.title == "Test Movie"
      assert result.media_type == :movie
      assert result.release_date == ~D[2023-01-15]
      assert result.overview == "A test movie overview"
      assert result.poster_path == "/test_poster.jpg"
      assert result.genre_ids == [28, 12]
      assert result.vote_average == 7.5
      assert result.popularity == 85.2
    end

    test "creates SearchResult from valid TV show data" do
      tv_data = %{
        "id" => 456,
        "name" => "Test TV Show",
        "media_type" => "tv",
        "first_air_date" => "2022-05-20",
        "overview" => "A test TV show overview",
        "poster_path" => "/test_tv_poster.jpg",
        "genre_ids" => [18, 35],
        "vote_average" => 8.2,
        "popularity" => 92.1
      }

      assert {:ok, result} = SearchResult.from_tmdb_data(tv_data)
      assert result.id == 456
      assert result.title == "Test TV Show"
      assert result.media_type == :tv
      assert result.release_date == ~D[2022-05-20]
      assert result.overview == "A test TV show overview"
      assert result.poster_path == "/test_tv_poster.jpg"
      assert result.genre_ids == [18, 35]
      assert result.vote_average == 8.2
      assert result.popularity == 92.1
    end

    test "handles minimal required data" do
      minimal_data = %{
        "id" => 789,
        "media_type" => "movie"
      }

      assert {:ok, result} = SearchResult.from_tmdb_data(minimal_data)
      assert result.id == 789
      assert result.title == "Unknown Title"
      assert result.media_type == :movie
      assert result.release_date == nil
      assert result.overview == nil
      assert result.poster_path == nil
      assert result.genre_ids == []
      assert result.vote_average == 0.0
      assert result.popularity == 0.0
    end

    test "handles missing title gracefully" do
      data_without_title = %{
        "id" => 999,
        "media_type" => "tv",
        "overview" => "No title provided"
      }

      assert {:ok, result} = SearchResult.from_tmdb_data(data_without_title)
      assert result.title == "Unknown Title"
    end

    test "handles invalid date formats" do
      data_with_invalid_date = %{
        "id" => 111,
        "title" => "Invalid Date Movie",
        "media_type" => "movie",
        "release_date" => "invalid-date"
      }

      assert {:ok, result} = SearchResult.from_tmdb_data(data_with_invalid_date)
      assert result.release_date == nil
    end

    test "handles empty date strings" do
      data_with_empty_date = %{
        "id" => 222,
        "title" => "Empty Date Movie",
        "media_type" => "movie",
        "release_date" => ""
      }

      assert {:ok, result} = SearchResult.from_tmdb_data(data_with_empty_date)
      assert result.release_date == nil
    end

    test "defaults unknown media_type to movie" do
      data_with_unknown_type = %{
        "id" => 333,
        "title" => "Unknown Type",
        "media_type" => "unknown"
      }

      assert {:ok, result} = SearchResult.from_tmdb_data(data_with_unknown_type)
      assert result.media_type == :movie
    end

    test "returns error for missing required fields" do
      incomplete_data = %{
        "title" => "Missing ID"
      }

      assert {:error, error_msg} = SearchResult.from_tmdb_data(incomplete_data)
      assert error_msg =~ "Missing required fields"
    end

    test "returns error for invalid data format" do
      assert {:error, "Invalid data format"} = SearchResult.from_tmdb_data("not a map")
      assert {:error, "Invalid data format"} = SearchResult.from_tmdb_data(nil)
      assert {:error, "Invalid data format"} = SearchResult.from_tmdb_data(123)
    end
  end

  describe "struct validation" do
    test "creates valid SearchResult struct" do
      result = %SearchResult{
        id: 1,
        title: "Test",
        media_type: :movie,
        release_date: ~D[2023-01-01],
        overview: "Overview",
        poster_path: "/poster.jpg",
        genre_ids: [1, 2],
        vote_average: 7.0,
        popularity: 80.0
      }

      assert result.id == 1
      assert result.title == "Test"
      assert result.media_type == :movie
    end
  end
end
