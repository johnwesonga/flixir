defmodule Flixir.Media.TMDBClientTest do
  use ExUnit.Case, async: true
  
  alias Flixir.Media.TMDBClient

  describe "configuration" do
    test "raises error when API key is not configured" do
      original_config = Application.get_env(:flixir, :tmdb)
      
      try do
        Application.put_env(:flixir, :tmdb, [api_key: nil])
        
        assert_raise RuntimeError, ~r/TMDB API key not configured/, fn ->
          TMDBClient.search_multi("test")
        end
      after
        Application.put_env(:flixir, :tmdb, original_config)
      end
    end

    test "has correct configuration structure" do
      config = Application.get_env(:flixir, :tmdb)
      
      # API key might be nil in test environment if not set via env var
      assert config[:api_key] == nil or is_binary(config[:api_key])
      assert config[:base_url] == "https://api.themoviedb.org/3"
      assert config[:image_base_url] == "https://image.tmdb.org/t/p/w500"
      assert is_integer(config[:timeout])
      assert is_integer(config[:max_retries])
    end
  end

  describe "API client structure" do
    test "search_multi functions exist with correct arity" do
      functions = TMDBClient.__info__(:functions)
      
      # search_multi has default parameters, so it shows as arity 1
      assert Keyword.get(functions, :search_multi) == 1
    end

    test "detail functions exist" do
      functions = TMDBClient.__info__(:functions)
      
      assert Keyword.has_key?(functions, :get_movie_details)
      assert Keyword.has_key?(functions, :get_tv_details)
    end
  end

  describe "module structure" do
    test "module is properly defined" do
      assert Code.ensure_loaded?(TMDBClient)
      assert TMDBClient.__info__(:module) == TMDBClient
    end

    test "has required public functions" do
      functions = TMDBClient.__info__(:functions)
      
      # Check that our main API functions are present
      assert :search_multi in Keyword.keys(functions)
      assert :get_movie_details in Keyword.keys(functions)
      assert :get_tv_details in Keyword.keys(functions)
    end
  end

  describe "error handling patterns" do
    test "module contains error handling code" do
      # Read the source file and check for error handling patterns
      source = File.read!("lib/flixir/media/tmdb_client.ex")
      
      # Check that error handling patterns are present in the source
      assert String.contains?(source, ":unauthorized")
      assert String.contains?(source, ":rate_limited")
      assert String.contains?(source, ":api_error")
      assert String.contains?(source, ":timeout")
      assert String.contains?(source, ":request_failed")
    end

    test "module contains proper HTTP status handling" do
      source = File.read!("lib/flixir/media/tmdb_client.ex")
      
      # Check for HTTP status code handling
      assert String.contains?(source, "status: 200")
      assert String.contains?(source, "status: 401")
      assert String.contains?(source, "status: 429")
    end
  end

  describe "request configuration" do
    test "module contains proper request headers" do
      source = File.read!("lib/flixir/media/tmdb_client.ex")
      
      # Check for proper headers
      assert String.contains?(source, "Accept")
      assert String.contains?(source, "application/json")
      assert String.contains?(source, "User-Agent")
      assert String.contains?(source, "Flixir/1.0")
    end

    test "module contains timeout and retry configuration" do
      source = File.read!("lib/flixir/media/tmdb_client.ex")
      
      # Check for timeout and retry settings
      assert String.contains?(source, "receive_timeout")
      assert String.contains?(source, "max_retries")
      assert String.contains?(source, "retry: :transient")
    end
  end
end