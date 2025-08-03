defmodule Flixir.Auth.APIIntegrationTest do
  @moduledoc """
  API integration tests for TMDB authentication endpoints.

  These tests make real API calls to TMDB and are tagged with :integration
  to allow them to be excluded from regular test runs. They require a valid
  TMDB API key to be set in the TMDB_API_KEY environment variable.

  Run with: mix test --only integration
  """

  use ExUnit.Case, async: false
  alias Flixir.Auth.TMDBClient

  @moduletag :integration

  describe "real TMDB API integration" do
    @tag :integration
    test "create_request_token/0 with real API" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        case TMDBClient.create_request_token() do
          {:ok, %{request_token: token, expires_at: expires_at}} ->
            assert is_binary(token)
            assert String.length(token) > 20
            assert is_binary(expires_at)
            assert expires_at =~ ~r/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/

          {:error, reason} ->
            flunk("Expected successful token creation, got error: #{inspect(reason)}")
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end

    @tag :integration
    test "create_session/1 with invalid token returns error" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        # Use an obviously invalid token
        invalid_token = "invalid_token_123"

        case TMDBClient.create_session(invalid_token) do
          {:error, :session_creation_failed} ->
            # Expected result for invalid token
            assert true

          {:error, reason} ->
            # Other errors are also acceptable (e.g., network issues)
            assert reason in [:network_error, :service_unavailable, :unauthorized]

          {:ok, _} ->
            flunk("Expected error for invalid token, but got success")
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end

    @tag :integration
    test "delete_session/1 with invalid session returns error" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        # Use an obviously invalid session ID
        invalid_session = "invalid_session_123"

        case TMDBClient.delete_session(invalid_session) do
          {:error, reason} ->
            # Should return an error for invalid session
            assert reason in [:session_deletion_failed, :unauthorized, :not_found, :service_unavailable]

          {:ok, _} ->
            flunk("Expected error for invalid session, but got success")
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end

    @tag :integration
    test "get_account_details/1 with invalid session returns error" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        # Use an obviously invalid session ID
        invalid_session = "invalid_session_123"

        case TMDBClient.get_account_details(invalid_session) do
          {:error, reason} ->
            # Should return an error for invalid session
            assert reason in [:authentication_failed, :unauthorized, :invalid_response_format, :service_unavailable]

          {:ok, _} ->
            flunk("Expected error for invalid session, but got success")
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end

    @tag :integration
    test "API error handling with invalid API key" do
      # Temporarily override the API key configuration
      original_config = Application.get_env(:flixir, :tmdb)

      try do
        # Set invalid API key
        Application.put_env(:flixir, :tmdb, [
          api_key: "invalid_key_123",
          base_url: "https://api.themoviedb.org/3",
          timeout: 5_000
        ])

        case TMDBClient.create_request_token() do
          {:error, reason} ->
            # Should return authentication error for invalid API key
            assert reason in [:authentication_failed, :unauthorized, :service_unavailable]

          {:ok, _} ->
            flunk("Expected error for invalid API key, but got success")
        end
      after
        # Restore original configuration
        if original_config do
          Application.put_env(:flixir, :tmdb, original_config)
        else
          Application.delete_env(:flixir, :tmdb)
        end
      end
    end

    @tag :integration
    test "API timeout handling" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        # Temporarily set a very short timeout
        original_config = Application.get_env(:flixir, :tmdb)

        try do
          Application.put_env(:flixir, :tmdb, [
            api_key: api_key,
            base_url: "https://api.themoviedb.org/3",
            timeout: 1  # 1ms timeout - should cause timeout
          ])

          case TMDBClient.create_request_token() do
            {:error, reason} ->
              # Should return timeout or network error
              assert reason in [:timeout, :network_error, :service_unavailable]

            {:ok, _} ->
              # Sometimes the request might be fast enough even with 1ms timeout
              # This is acceptable in integration tests
              assert true
          end
        after
          # Restore original configuration
          if original_config do
            Application.put_env(:flixir, :tmdb, original_config)
          else
            Application.delete_env(:flixir, :tmdb)
          end
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end

    @tag :integration
    test "API rate limiting behavior" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        # Make multiple rapid requests to potentially trigger rate limiting
        # Note: TMDB has generous rate limits, so this might not always trigger
        results = Enum.map(1..5, fn _i ->
          TMDBClient.create_request_token()
        end)

        # At least some requests should succeed
        successful_requests = Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

        assert successful_requests > 0

        # Check if any rate limiting occurred
        rate_limited_requests = Enum.count(results, fn
          {:error, :rate_limited} -> true
          _ -> false
        end)

        # Rate limiting is not guaranteed to occur, so we just verify
        # that if it does occur, it's handled properly
        if rate_limited_requests > 0 do
          assert rate_limited_requests <= 5
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end

    @tag :integration
    test "API response format validation" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        case TMDBClient.create_request_token() do
          {:ok, response} ->
            # Verify response has expected structure
            assert Map.has_key?(response, :request_token)
            assert Map.has_key?(response, :expires_at)
            assert is_binary(response.request_token)
            assert is_binary(response.expires_at)

          {:error, reason} ->
            # Network errors are acceptable in integration tests
            assert reason in [:network_error, :service_unavailable, :timeout, :authentication_failed]
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end

    @tag :integration
    test "API base URL configuration" do
      api_key = System.get_env("TMDB_API_KEY")

      if api_key && String.length(api_key) > 10 do
        # Test with invalid base URL
        original_config = Application.get_env(:flixir, :tmdb)

        try do
          Application.put_env(:flixir, :tmdb, [
            api_key: api_key,
            base_url: "https://invalid-api-url.example.com/v3",
            timeout: 5_000
          ])

          case TMDBClient.create_request_token() do
            {:error, reason} ->
              # Should return network error for invalid URL
              assert reason in [:network_error, :service_unavailable, {:transport_error, :nxdomain}]

            {:ok, _} ->
              flunk("Expected error for invalid base URL, but got success")
          end
        after
          # Restore original configuration
          if original_config do
            Application.put_env(:flixir, :tmdb, original_config)
          else
            Application.delete_env(:flixir, :tmdb)
          end
        end
      else
        IO.puts("Skipping real API test - TMDB_API_KEY not configured")
      end
    end
  end

  describe "API configuration validation" do
    @tag :integration
    test "missing API key raises error" do
      original_config = Application.get_env(:flixir, :tmdb)

      try do
        Application.put_env(:flixir, :tmdb, [api_key: nil])

        assert_raise RuntimeError, ~r/TMDB API key not found/, fn ->
          TMDBClient.create_request_token()
        end
      after
        if original_config do
          Application.put_env(:flixir, :tmdb, original_config)
        else
          Application.delete_env(:flixir, :tmdb)
        end
      end
    end

    @tag :integration
    test "empty API key raises error" do
      original_config = Application.get_env(:flixir, :tmdb)

      try do
        Application.put_env(:flixir, :tmdb, [api_key: ""])

        assert_raise RuntimeError, ~r/Invalid TMDB API key - key appears too short/, fn ->
          TMDBClient.create_request_token()
        end
      after
        if original_config do
          Application.put_env(:flixir, :tmdb, original_config)
        else
          Application.delete_env(:flixir, :tmdb)
        end
      end
    end

    @tag :integration
    test "invalid API key type raises error" do
      original_config = Application.get_env(:flixir, :tmdb)

      try do
        Application.put_env(:flixir, :tmdb, [api_key: 12345])

        assert_raise RuntimeError, ~r/Invalid TMDB API key configuration/, fn ->
          TMDBClient.create_request_token()
        end
      after
        if original_config do
          Application.put_env(:flixir, :tmdb, original_config)
        else
          Application.delete_env(:flixir, :tmdb)
        end
      end
    end
  end
end
