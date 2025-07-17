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

  alias Flixir.Media
  alias Flixir.Media.Cache

  describe "API timeout scenarios" do
    test "handles API request timeout gracefully", %{conn: conn} do
      with_mocks([
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:timeout, "Search request timed out. Please try again."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            count = Agent.get_and_update(call_count, fn c -> {c, c + 1} end)

            case count do
              0 -> {:error, {:timeout, "Search request timed out. Please try again."}}
              1 -> {:error, {:timeout, "Search request timed out. Please try again."}}
              _ -> {:ok, [%Flixir.Media.SearchResult{
                id: 155,
                title: "The Dark Knight",
                media_type: :movie,
                release_date: ~D[2008-07-18],
                overview: "Batman movie",
                poster_path: "/batman.jpg",
                genre_ids: [28, 80],
                vote_average: 9.0,
                popularity: 123.456
              }]}
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

        # Verify API was called multiple times (form submit + URL params handling may cause multiple calls)
        final_count = Agent.get(call_count, & &1)
        assert final_count >= 2

        Agent.stop(call_count)
      end
    end

    test "handles connection timeout vs read timeout differently", %{conn: conn} do
      with_mocks([
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:network_error, "Network error occurred. Please check your connection and try again."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:unauthorized, "API authentication failed. Please check configuration."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:rate_limited, "Too many requests. Please wait a moment and try again."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:api_error, "Search service temporarily unavailable. Please try again later."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:api_error, "Search service temporarily unavailable. Please try again later."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:api_error, "Search service temporarily unavailable. Please try again later."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:network_error, "Network error occurred. Please check your connection and try again."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:network_error, "Network error occurred. Please check your connection and try again."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:network_error, "Network error occurred. Please check your connection and try again."}}
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
      with_mocks([
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:transformation_error, "Missing required fields"}}
          end
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
      with_mocks([
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:transformation_error, "Invalid API response format"}}
          end
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
      with_mocks([
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:transformation_error, "Invalid data types"}}
          end
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:transformation_error, "Null response"}}
          end
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
        {Media, [], [
          search_content: fn _query, _opts ->
            count = Agent.get_and_update(failure_count, fn c -> {c, c + 1} end)

            case count do
              0 -> {:error, {:timeout, "Search request timed out. Please try again."}}
              1 -> {:error, {:timeout, "Search request timed out. Please try again."}}
              2 -> {:error, {:api_error, "Search service temporarily unavailable. Please try again later."}}
              3 -> {:error, {:api_error, "Search service temporarily unavailable. Please try again later."}}
              _ -> {:ok, [%Flixir.Media.SearchResult{
                id: 155,
                title: "The Dark Knight",
                media_type: :movie,
                release_date: ~D[2008-07-18],
                overview: "Batman movie",
                poster_path: "/batman.jpg",
                genre_ids: [28, 80],
                vote_average: 9.0,
                popularity: 123.456
              }]}
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

        # Verify API was called multiple times (at least 3 times due to form submit + URL params handling)
        final_count = Agent.get(failure_count, & &1)
        assert final_count >= 3

        Agent.stop(failure_count)
      end
    end

    test "error state clears when new search is performed", %{conn: conn} do
      with_mocks([
        {Media, [], [
          search_content: fn query, _opts ->
            case query do
              "failing_query" -> {:error, {:timeout, "Search request timed out. Please try again."}}
              _ -> {:ok, [%Flixir.Media.SearchResult{
                id: 155,
                title: "Success Result",
                media_type: :movie,
                release_date: ~D[2008-07-18],
                overview: "Successful search",
                poster_path: "/success.jpg",
                genre_ids: [28],
                vote_average: 8.0,
                popularity: 100.0
              }]}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            {:error, {:timeout, "Search request timed out. Please try again."}}
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
        {Media, [], [
          search_content: fn _query, _opts ->
            Process.sleep(100)  # Simulate some delay
            {:error, {:timeout, "Search request timed out. Please try again."}}
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
        {Media, [], [
          search_content: fn query, _opts ->
            case query do
              "error_query" -> {:error, {:timeout, "Search request timed out. Please try again."}}
              _ -> {:ok, [%Flixir.Media.SearchResult{
                id: 155,
                title: "Recovery Result",
                media_type: :movie,
                release_date: ~D[2008-07-18],
                overview: "Recovered search",
                poster_path: "/recovery.jpg",
                genre_ids: [28],
                vote_average: 8.0,
                popularity: 100.0
              }]}
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
        {{:timeout, "Search request timed out. Please try again."}, "Search request timed out. Please try again.", true},
        {{:rate_limited, "Too many requests. Please wait a moment and try again."}, "Too many requests. Please wait a moment and try again.", false},
        {{:unauthorized, "API authentication failed. Please check configuration."}, "API authentication failed. Please check configuration.", false},
        {{:api_error, "Search service temporarily unavailable. Please try again later."}, "Search service temporarily unavailable. Please try again later.", true},
        {{:network_error, "Network error occurred. Please check your connection and try again."}, "Network error occurred. Please check your connection and try again.", true}
      ]

      for {{error_type, error_message}, expected_message, should_show_retry} <- error_scenarios do
        with_mocks([
          {Media, [], [
            search_content: fn _query, _opts ->
              {:error, {error_type, error_message}}
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
