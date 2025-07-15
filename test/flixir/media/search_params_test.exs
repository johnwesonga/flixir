defmodule Flixir.Media.SearchParamsTest do
  use ExUnit.Case, async: true

  alias Flixir.Media.SearchParams

  describe "new/1" do
    test "creates SearchParams with valid parameters" do
      params = %{
        "query" => "avengers",
        "media_type" => "movie",
        "sort_by" => "popularity",
        "page" => 2
      }

      assert {:ok, search_params} = SearchParams.new(params)
      assert search_params.query == "avengers"
      assert search_params.media_type == :movie
      assert search_params.sort_by == :popularity
      assert search_params.page == 2
    end

    test "creates SearchParams with atom keys" do
      params = %{
        query: "batman",
        media_type: :tv,
        sort_by: :release_date,
        page: 1
      }

      assert {:ok, search_params} = SearchParams.new(params)
      assert search_params.query == "batman"
      assert search_params.media_type == :tv
      assert search_params.sort_by == :release_date
      assert search_params.page == 1
    end

    test "uses default values for missing parameters" do
      params = %{"query" => "spider-man"}

      assert {:ok, search_params} = SearchParams.new(params)
      assert search_params.query == "spider-man"
      assert search_params.media_type == :all
      assert search_params.sort_by == :relevance
      assert search_params.page == 1
    end

    test "trims whitespace from query" do
      params = %{"query" => "  superman  "}

      assert {:ok, search_params} = SearchParams.new(params)
      assert search_params.query == "superman"
    end

    test "returns error for invalid data format" do
      assert {:error, "Invalid parameters format"} = SearchParams.new("not a map")
      assert {:error, "Invalid parameters format"} = SearchParams.new(nil)
      assert {:error, "Invalid parameters format"} = SearchParams.new(123)
    end

    test "returns error for invalid query" do
      params = %{"query" => ""}
      assert {:error, error} = SearchParams.new(params)
      assert error =~ "Search query cannot be empty"
    end

    test "returns error for invalid media_type" do
      params = %{"query" => "test", "media_type" => "invalid"}
      assert {:error, error} = SearchParams.new(params)
      assert error =~ "Invalid media type"
    end

    test "returns error for invalid sort_by" do
      params = %{"query" => "test", "sort_by" => "invalid"}
      assert {:error, error} = SearchParams.new(params)
      assert error =~ "Invalid sort option"
    end

    test "returns error for invalid page" do
      params = %{"query" => "test", "page" => 0}
      assert {:error, error} = SearchParams.new(params)
      assert error =~ "Page number must be greater than 0"
    end
  end

  describe "validate_query/1" do
    test "validates valid queries" do
      assert {:ok, "avengers"} = SearchParams.validate_query("avengers")
      assert {:ok, "the dark knight"} = SearchParams.validate_query("the dark knight")
      assert {:ok, "test"} = SearchParams.validate_query("  test  ")
    end

    test "rejects empty queries" do
      assert {:error, error} = SearchParams.validate_query("")
      assert error =~ "Search query cannot be empty"
    end

    test "rejects whitespace-only queries" do
      assert {:error, error} = SearchParams.validate_query("   ")
      assert error =~ "Search query cannot be empty"
    end

    test "rejects queries that are too long" do
      long_query = String.duplicate("a", 201)
      assert {:error, error} = SearchParams.validate_query(long_query)
      assert error =~ "Search query is too long"
    end

    test "rejects non-string queries" do
      assert {:error, error} = SearchParams.validate_query(123)
      assert error =~ "Search query must be a string"
    end
  end

  describe "validate_media_type/1" do
    test "validates valid atom media types" do
      assert {:ok, :all} = SearchParams.validate_media_type(:all)
      assert {:ok, :movie} = SearchParams.validate_media_type(:movie)
      assert {:ok, :tv} = SearchParams.validate_media_type(:tv)
    end

    test "validates valid string media types" do
      assert {:ok, :all} = SearchParams.validate_media_type("all")
      assert {:ok, :movie} = SearchParams.validate_media_type("movie")
      assert {:ok, :tv} = SearchParams.validate_media_type("tv")
    end

    test "rejects invalid media types" do
      assert {:error, error} = SearchParams.validate_media_type(:invalid)
      assert error =~ "Invalid media type"

      assert {:error, error} = SearchParams.validate_media_type("invalid")
      assert error =~ "Invalid media type"
    end

    test "rejects non-atom/string media types" do
      assert {:error, error} = SearchParams.validate_media_type(123)
      assert error =~ "Media type must be an atom or string"
    end
  end

  describe "validate_sort_by/1" do
    test "validates valid atom sort options" do
      assert {:ok, :relevance} = SearchParams.validate_sort_by(:relevance)
      assert {:ok, :release_date} = SearchParams.validate_sort_by(:release_date)
      assert {:ok, :title} = SearchParams.validate_sort_by(:title)
      assert {:ok, :popularity} = SearchParams.validate_sort_by(:popularity)
    end

    test "validates valid string sort options" do
      assert {:ok, :relevance} = SearchParams.validate_sort_by("relevance")
      assert {:ok, :release_date} = SearchParams.validate_sort_by("release_date")
      assert {:ok, :title} = SearchParams.validate_sort_by("title")
      assert {:ok, :popularity} = SearchParams.validate_sort_by("popularity")
    end

    test "rejects invalid sort options" do
      assert {:error, error} = SearchParams.validate_sort_by(:invalid)
      assert error =~ "Invalid sort option"

      assert {:error, error} = SearchParams.validate_sort_by("invalid")
      assert error =~ "Invalid sort option"
    end

    test "rejects non-atom/string sort options" do
      assert {:error, error} = SearchParams.validate_sort_by(123)
      assert error =~ "Sort option must be an atom or string"
    end
  end

  describe "validate_page/1" do
    test "validates valid integer pages" do
      assert {:ok, 1} = SearchParams.validate_page(1)
      assert {:ok, 100} = SearchParams.validate_page(100)
      assert {:ok, 1000} = SearchParams.validate_page(1000)
    end

    test "validates valid string pages" do
      assert {:ok, 1} = SearchParams.validate_page("1")
      assert {:ok, 50} = SearchParams.validate_page("50")
    end

    test "rejects invalid page numbers" do
      assert {:error, error} = SearchParams.validate_page(0)
      assert error =~ "Page number must be greater than 0"

      assert {:error, error} = SearchParams.validate_page(-1)
      assert error =~ "Page number must be greater than 0"

      assert {:error, error} = SearchParams.validate_page(1001)
      assert error =~ "Page number cannot exceed 1000"
    end

    test "rejects invalid string pages" do
      assert {:error, error} = SearchParams.validate_page("invalid")
      assert error =~ "Page must be a valid integer"

      assert {:error, error} = SearchParams.validate_page("1.5")
      assert error =~ "Page must be a valid integer"
    end

    test "rejects non-integer/string pages" do
      assert {:error, error} = SearchParams.validate_page(1.5)
      assert error =~ "Page must be an integer"
    end
  end

  describe "to_api_params/1" do
    test "converts SearchParams to API parameters" do
      search_params = %SearchParams{
        query: "avengers",
        media_type: :all,
        sort_by: :relevance,
        page: 1
      }

      api_params = SearchParams.to_api_params(search_params)

      assert api_params["query"] == "avengers"
      assert api_params["page"] == 1
      refute Map.has_key?(api_params, "media_type")
    end

    test "includes media_type filter when not :all" do
      search_params = %SearchParams{
        query: "batman",
        media_type: :movie,
        sort_by: :popularity,
        page: 2
      }

      api_params = SearchParams.to_api_params(search_params)

      assert api_params["query"] == "batman"
      assert api_params["page"] == 2
      assert api_params["media_type"] == "movie"
    end

    test "includes TV media_type filter" do
      search_params = %SearchParams{
        query: "breaking bad",
        media_type: :tv,
        sort_by: :release_date,
        page: 1
      }

      api_params = SearchParams.to_api_params(search_params)

      assert api_params["media_type"] == "tv"
    end
  end

  describe "struct validation" do
    test "creates valid SearchParams struct" do
      search_params = %SearchParams{
        query: "test",
        media_type: :movie,
        sort_by: :popularity,
        page: 1
      }

      assert search_params.query == "test"
      assert search_params.media_type == :movie
      assert search_params.sort_by == :popularity
      assert search_params.page == 1
    end

    test "uses default values in struct" do
      search_params = %SearchParams{}

      assert search_params.query == ""
      assert search_params.media_type == :all
      assert search_params.sort_by == :relevance
      assert search_params.page == 1
    end
  end
end
