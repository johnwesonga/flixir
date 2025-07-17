defmodule FlixirWeb.Integration.ErrorHandlingTest do
  @moduledoc """
  Comprehensive tests for API timeout and error response handling.

  Tests cover:
  - Various API timeout scenarios
  - Different types of API errors (4xx, 5xx)
  - Network connectivity issues
  - Malformed API responses
  - Error recovery mechanisms
  - User experience during errors
  """

  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Media.{TMDBClient, Cache}

  describe "API timeout scenarios" do
    test "handles API request timeout gracefully", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "timeout_test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:timeout, "Request timed out"}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify timeout error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search request timed out. Please try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")

        # Verify no results are shown
        refute has_element?(view, "[data-testid='search-result-card']")
        refute has_element?(view, "[data-testid='results-count']")
      end
    end

    test "timeout error shows retry functionality", %{conn: conn} do
      call_count = Agent.start_link(fn -> 0 end)
      {:ok, call_count} = call_count

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "retry_timeout_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            count = Agent.get_and_update(call_count, fn c -> {c + 1, c + 1} end)

            case count do
              1 -> {:error, {:timeout, "Request timed out"}}
              _ -> {:ok, %{
                "results" => [%{
                  "id" => 155,
                  "title" => "The Dark Knight",
                  "media_type" => "movie",
                  "release_date" => "2008-07-18",
                  "overview" => "Batman movie",
                  "poster_path" => "/batman.jpg",
                  "genre_ids" => [28, 80],
                  "vote_average" => 9.0,
                  "popularity" => 123.456
                }]
              }}
            end
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Initial search that times out
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify timeout error
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")

        # Click retry button
        view
        |> element("[data-testid='retry-search-button']")
        |> render_click()

        # Verify retry succeeded
        assert has_element?(view, "[data-testid='search-result-card']", "The Dark Knight")
        refute has_element?(view, "[data-testid='api-error']")

        # Verify API was called twice
        final_count = Agent.get(call_count, & &1)
        assert final_count == 2

        Agent.stop(call_count)
      end
    end

    test "handles connection timeout vs read timeout differently", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "connection_timeout_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:request_failed, %Req.TransportError{reason: :timeout}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Should show network error message
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Network error occurred. Please check your connection and try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end
  end

  describe "API error responses" do
    test "handles 401 unauthorized error", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "unauthorized_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:unauthorized, "Invalid API key", %{"status_message" => "Invalid API key"}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify unauthorized error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "API authentication failed. Please check configuration.")

        # Unauthorized errors should not show retry button
        refute has_element?(view, "[data-testid='retry-search-button']")
      end
    end

    test "handles 429 rate limiting error", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "rate_limit_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:rate_limited, "Too many requests", %{"status_message" => "Request count over limit"}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify rate limiting error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Too many requests. Please wait a moment and try again.")

        # Rate limiting errors should not show retry button
        refute has_element?(view, "[data-testid='retry-search-button']")
      end
    end

    test "handles 404 not found error", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "not_found_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:api_error, 404, %{"status_message" => "The resource you requested could not be found."}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "nonexistent"})
        |> render_submit()

        # Verify API error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search service temporarily unavailable. Please try again later.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end

    test "handles 500 internal server error", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "server_error_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:api_error, 500, %{"status_message" => "Internal server error"}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify server error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search service temporarily unavailable. Please try again later.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end

    test "handles 503 service unavailable error", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "service_unavailable_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:api_error, 503, %{"status_message" => "Service temporarily unavailable"}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify service unavailable error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search service temporarily unavailable. Please try again later.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end
  end

  describe "network connectivity issues" do
    test "handles connection refused error", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "connection_refused_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:request_failed, %Req.TransportError{reason: :econnrefused}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify network error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Network error occurred. Please check your connection and try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end

    test "handles DNS resolution failure", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "dns_failure_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:request_failed, %Req.TransportError{reason: :nxdomain}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify network error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Network error occurred. Please check your connection and try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end

    test "handles SSL/TLS certificate errors", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "ssl_error_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:request_failed, {:tls_alert, {:certificate_expired, "certificate expired"}}}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify network error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Network error occurred. Please check your connection and try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end
  end

  describe "malformed API responses" do
    test "handles response with missing required fields", %{conn: conn} do
      malformed_response = %{
        "results" => [
          %{
            "id" => 155,
            # Missing title and media_type
            "release_date" => "2008-07-18",
            "overview" => "Batman movie"
          }
        ]
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "malformed_response_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, malformed_response} end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify transformation error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Unable to process search results. Please try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end

    test "handles response with invalid JSON structure", %{conn: conn} do
      invalid_response = %{
        "invalid_field" => "invalid_value",
        # Missing results field
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "invalid_json_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, invalid_response} end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify transformation error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Unable to process search results. Please try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end

    test "handles response with invalid data types", %{conn: conn} do
      invalid_types_response = %{
        "results" => [
          %{
            "id" => "not_an_integer",  # Should be integer
            "title" => 12345,          # Should be string
            "media_type" => "movie",
            "release_date" => "invalid-date",  # Invalid date format
            "vote_average" => "not_a_number"   # Should be number
          }
        ]
      }

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "invalid_types_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, invalid_types_response} end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify transformation error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Unable to process search results. Please try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end

    test "handles empty or null response", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "null_response_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, nil} end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify transformation error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Unable to process search results. Please try again.")
        assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
      end
    end
  end

  describe "error recovery mechanisms" do
    test "successful retry after multiple failures", %{conn: conn} do
      failure_count = Agent.start_link(fn -> 0 end)
      {:ok, failure_count} = failure_count

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "recovery_test_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            count = Agent.get_and_update(failure_count, fn c -> {c + 1, c + 1} end)

            case count do
              1 -> {:error, {:timeout, "Request timed out"}}
              2 -> {:error, {:api_error, 500, %{"status_message" => "Internal server error"}}}
              _ -> {:ok, %{
                "results" => [%{
                  "id" => 155,
                  "title" => "The Dark Knight",
                  "media_type" => "movie",
                  "release_date" => "2008-07-18",
                  "overview" => "Batman movie",
                  "poster_path" => "/batman.jpg",
                  "genre_ids" => [28, 80],
                  "vote_average" => 9.0,
                  "popularity" => 123.456
                }]
              }}
            end
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # First search - timeout error
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search request timed out. Please try again.")

        # First retry - server error
        view
        |> element("[data-testid='retry-search-button']")
        |> render_click()

        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search service temporarily unavailable. Please try again later.")

        # Second retry - success
        view
        |> element("[data-testid='retry-search-button']")
        |> render_click()

        # Verify success
        assert has_element?(view, "[data-testid='search-result-card']", "The Dark Knight")
        refute has_element?(view, "[data-testid='api-error']")

        # Verify API was called 3 times
        final_count = Agent.get(failure_count, & &1)
        assert final_count == 3

        Agent.stop(failure_count)
      end
    end

    test "error state clears when new search is performed", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn query, _opts -> "clear_error_#{query}" end
        ]},
        {TMDBClient, [], [
          search_multi: fn query, _page ->
            case query do
              "failing_query" -> {:error, {:timeout, "Request timed out"}}
              _ -> {:ok, %{
                "results" => [%{
                  "id" => 155,
                  "title" => "Success Result",
                  "media_type" => "movie",
                  "release_date" => "2008-07-18",
                  "overview" => "Successful search",
                  "poster_path" => "/success.jpg",
                  "genre_ids" => [28],
                  "vote_average" => 8.0,
                  "popularity" => 100.0
                }]
              }}
            end
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Search that fails
        view
        |> form("#search-form", search: %{query: "failing_query"})
        |> render_submit()

        # Verify error is displayed
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search request timed out. Please try again.")

        # Perform new search that succeeds
        view
        |> form("#search-form", search: %{query: "success_query"})
        |> render_submit()

        # Verify error is cleared and results are shown
        refute has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, "[data-testid='search-result-card']", "Success Result")
      end
    end

    test "error state persists across filter changes", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "persistent_error_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            {:error, {:timeout, "Request timed out"}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Search that fails
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify error is displayed
        assert has_element?(view, "[data-testid='api-error']")

        # Try to change filters
        view
        |> form("form[phx-change='update_filters']")
        |> render_change(%{filters: %{media_type: "movie"}})

        # Error should still be displayed (no new search performed)
        assert has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, ".text-red-600", "Search request timed out. Please try again.")
      end
    end
  end

  describe "user experience during errors" do
    test "loading state is cleared when error occurs", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          search_key: fn _query, _opts -> "loading_error_key" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            Process.sleep(100)  # Simulate some delay
            {:error, {:timeout, "Request timed out"}}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Perform search
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Wait for error to appear
        Process.sleep(200)

        # Verify loading state is cleared and error is shown
        refute has_element?(view, "[data-testid='loading-spinner']")
        assert has_element?(view, "[data-testid='api-error']")
      end
    end

    test "search input remains functional during error state", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn query, _opts -> "input_functional_#{query}" end
        ]},
        {TMDBClient, [], [
          search_multi: fn query, _page ->
            case query do
              "error_query" -> {:error, {:timeout, "Request timed out"}}
              _ -> {:ok, %{
                "results" => [%{
                  "id" => 155,
                  "title" => "Recovery Result",
                  "media_type" => "movie",
                  "release_date" => "2008-07-18",
                  "overview" => "Recovered search",
                  "poster_path" => "/recovery.jpg",
                  "genre_ids" => [28],
                  "vote_average" => 8.0,
                  "popularity" => 100.0
                }]
              }}
            end
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Search that fails
        view
        |> form("#search-form", search: %{query: "error_query"})
        |> render_submit()

        # Verify error is displayed
        assert has_element?(view, "[data-testid='api-error']")

        # Verify search input is still functional
        assert has_element?(view, "input[name='search[query]']")
        refute has_element?(view, "input[disabled]")

        # Perform new search
        view
        |> form("#search-form", search: %{query: "recovery_query"})
        |> render_submit()

        # Verify recovery
        refute has_element?(view, "[data-testid='api-error']")
        assert has_element?(view, "[data-testid='search-result-card']", "Recovery Result")
      end
    end

    test "error messages are user-friendly and actionable", %{conn: conn} do
      error_scenarios = [
        {{:timeout, "Request timed out"}, "Search request timed out. Please try again.", true},
        {{:rate_limited, "Too many requests", %{}}, "Too many requests. Please wait a moment and try again.", false},
        {{:unauthorized, "Invalid API key", %{}}, "API authentication failed. Please check configuration.", false},
        {{:api_error, 500, %{}}, "Search service temporarily unavailable. Please try again later.", true},
        {{:network_error, "Network error"}, "Network error occurred. Please check your connection and try again.", true}
      ]

      for {{error_type, error_message, error_data}, expected_message, should_show_retry} <- error_scenarios do
        with_mocks([
          {Cache, [], [
            get: fn _key -> :error end,
            search_key: fn _query, _opts -> "user_friendly_#{error_type}" end
          ]},
          {TMDBClient, [], [
            search_multi: fn _query, _page ->
              case error_type do
                :timeout -> {:error, {error_type, error_message}}
                :rate_limited -> {:error, {error_type, error_message, error_data}}
                :unauthorized -> {:error, {error_type, error_message, error_data}}
                :api_error -> {:error, {error_type, 500, error_data}}
                :network_error -> {:error, {error_type, error_message}}
              end
            end
          ]}
        ]) do
          {:ok, view, _html} = live(conn, ~p"/search")

          view
          |> form("#search-form", search: %{query: "test"})
          |> render_submit()

          # Verify user-friendly error message
          assert has_element?(view, "[data-testid='api-error']")
          assert has_element?(view, ".text-red-600", expected_message)

          # Verify retry button presence
          if should_show_retry do
            assert has_element?(view, "[data-testid='retry-search-button']", "Try again")
          else
            refute has_element?(view, "[data-testid='retry-search-button']")
          end
        end
      end
    end
  end
end
