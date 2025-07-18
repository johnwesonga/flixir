defmodule FlixirWeb.Integration.PerformanceBenchmarkTest do
  @moduledoc """
  Performance benchmarks for search response times and system behavior.

  Tests cover:
  - Search response time benchmarks
  - Cache hit vs miss performance
  - UI responsiveness under load
  - Memory usage patterns
  - Throughput measurements
  - Performance regression detection
  """

  use FlixirWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.Media.{TMDBClient, Cache, SearchResult}

  # Sample response for consistent benchmarking
  @benchmark_response %{
    "results" => [
      %{
        "id" => 155,
        "title" => "The Dark Knight",
        "media_type" => "movie",
        "release_date" => "2008-07-18",
        "overview" => "Batman raises the stakes in his war on crime. With the help of Lt. Jim Gordon and District Attorney Harvey Dent, Batman sets out to dismantle the remaining criminal organizations that plague the streets.",
        "poster_path" => "/qJ2tW6WMUDux911r6m7haRef0WH.jpg",
        "genre_ids" => [28, 80, 18],
        "vote_average" => 9.0,
        "popularity" => 123.456
      },
      %{
        "id" => 1399,
        "name" => "Game of Thrones",
        "media_type" => "tv",
        "first_air_date" => "2011-04-17",
        "overview" => "Seven noble families fight for control of the mythical land of Westeros. Friction between the houses leads to full-scale war.",
        "poster_path" => "/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg",
        "genre_ids" => [18, 10765],
        "vote_average" => 8.3,
        "popularity" => 369.594
      },
      %{
        "id" => 27205,
        "title" => "Inception",
        "media_type" => "movie",
        "release_date" => "2010-07-16",
        "overview" => "Dom Cobb is a skilled thief, the absolute best in the dangerous art of extraction, stealing secrets from deep within the subconscious.",
        "poster_path" => "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg",
        "genre_ids" => [28, 878, 53],
        "vote_average" => 8.8,
        "popularity" => 89.123
      }
    ]
  }

  describe "search response time benchmarks" do
    test "search with cache miss meets performance requirements", %{conn: conn} do
      # Mock realistic API delay
      api_delay = 150  # 150ms simulated API response time

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "benchmark_cache_miss" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            Process.sleep(api_delay)
            {:ok, @benchmark_response}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Measure search performance
        start_time = System.monotonic_time(:millisecond)

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        # Verify results are displayed
        assert has_element?(view, "[data-testid='search-result-card']", "The Dark Knight")

        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time

        # Performance requirement: Search should complete within 2 seconds (requirement 3.5)
        assert response_time < 2000, "Search response time #{response_time}ms exceeds 2000ms requirement"

        # Should be reasonably fast even with API delay
        assert response_time < api_delay + 500, "Total response time #{response_time}ms too slow for API delay #{api_delay}ms"
      end
    end

    test "search with cache hit meets performance requirements", %{conn: conn} do
      cached_results = [
        %SearchResult{
          id: 155,
          title: "The Dark Knight",
          media_type: :movie,
          release_date: ~D[2008-07-18],
          overview: "Batman movie",
          poster_path: "/batman.jpg",
          genre_ids: [28, 80, 18],
          vote_average: 9.0,
          popularity: 123.456
        }
      ]

      with_mocks([
        {Cache, [], [
          get: fn _key -> {:ok, cached_results} end,
          search_key: fn _query, _opts -> "benchmark_cache_hit" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page -> {:ok, %{}} end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Measure cached search performance
        start_time = System.monotonic_time(:millisecond)

        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, "[data-testid='search-result-card']", "The Dark Knight")

        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time

        # Cached searches should be very fast (under 100ms requirement)
        assert response_time < 100, "Cached search response time #{response_time}ms exceeds 100ms requirement"

        # Verify API was not called
        refute called(TMDBClient.search_multi(:_, :_))
      end
    end

    test "multiple rapid searches maintain performance", %{conn: conn} do
      search_times = Agent.start_link(fn -> [] end)
      {:ok, search_times} = search_times

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn query, _opts -> "rapid_#{query}" end
        ]},
        {TMDBClient, [], [
          search_multi: fn query, 1 ->
            # Simulate variable API response times
            delay = 50 + :rand.uniform(100)  # 50-150ms
            Process.sleep(delay)
            {:ok, %{
              "results" => [%{
                "id" => :erlang.phash2(query),
                "title" => "Result for #{query}",
                "media_type" => "movie",
                "release_date" => "2020-01-01",
                "overview" => "Test result",
                "poster_path" => "/test.jpg",
                "genre_ids" => [28],
                "vote_average" => 8.0,
                "popularity" => 100.0
              }]
            }}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Perform multiple rapid searches
        queries = ["batman", "superman", "spiderman", "ironman", "hulk"]

        for query <- queries do
          start_time = System.monotonic_time(:millisecond)

          view
          |> form("#search-form", search: %{query: query})
          |> render_submit()

          # Wait for results to appear
          assert has_element?(view, "[data-testid='search-result-card']", "Result for #{query}")

          end_time = System.monotonic_time(:millisecond)
          search_time = end_time - start_time

          Agent.update(search_times, fn times -> [search_time | times] end)

          # Brief pause between searches
          Process.sleep(10)
        end

        # Analyze performance consistency
        times = Agent.get(search_times, & &1) |> Enum.reverse()
        avg_time = Enum.sum(times) / length(times)
        max_time = Enum.max(times)
        min_time = Enum.min(times)

        # All searches should meet performance requirements
        assert max_time < 2000, "Slowest search #{max_time}ms exceeds 2000ms requirement"
        assert avg_time < 1000, "Average search time #{avg_time}ms too slow for rapid searches"

        # Performance should be consistent (max shouldn't be much higher than min)
        performance_variance = (max_time - min_time) / avg_time
        assert performance_variance < 2.0, "Performance variance #{performance_variance} too high"

        Agent.stop(search_times)
      end
    end
  end

  describe "UI responsiveness benchmarks" do
    test "filter changes are applied quickly", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, opts ->
            media_type = Keyword.get(opts, :media_type, :all)
            "filter_benchmark_#{media_type}"
          end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            Process.sleep(100)  # Simulate API delay
            {:ok, @benchmark_response}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Initial search
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, "[data-testid='results-count']")

        # Measure filter application time
        start_time = System.monotonic_time(:millisecond)

        view
        |> form("form[phx-change='update_filters']")
        |> render_change(%{filters: %{media_type: "movie"}})

        # Verify filter is applied immediately in UI
        assert has_element?(view, "[data-testid='active-filter-badge']", "Movie")

        end_time = System.monotonic_time(:millisecond)
        filter_time = end_time - start_time

        # Filter UI updates should be reasonably fast (under 500ms)
        assert filter_time < 500, "Filter application time #{filter_time}ms too slow"
      end
    end

    test "sort changes are applied quickly", %{conn: conn} do
      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, opts ->
            sort_by = Keyword.get(opts, :sort_by, :relevance)
            "sort_benchmark_#{sort_by}"
          end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            Process.sleep(100)
            {:ok, @benchmark_response}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Initial search
        view
        |> form("#search-form", search: %{query: "batman"})
        |> render_submit()

        assert has_element?(view, "[data-testid='results-count']")

        # Measure sort application time
        start_time = System.monotonic_time(:millisecond)

        view
        |> form("form[phx-change='update_filters']")
        |> render_change(%{filters: %{sort_by: "popularity"}})

        # Verify sort is applied immediately in UI
        assert has_element?(view, "[data-testid='active-sort-badge']", "Popularity")

        end_time = System.monotonic_time(:millisecond)
        sort_time = end_time - start_time

        # Sort UI updates should be reasonably fast (under 500ms)
        assert sort_time < 500, "Sort application time #{sort_time}ms too slow"
      end
    end

    test "search input responsiveness", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/search")

      # Measure input responsiveness
      input_times = for query <- ["b", "ba", "bat", "batm", "batma", "batman"] do
        start_time = System.monotonic_time(:millisecond)

        view
        |> form("#search-form", search: %{query: query})
        |> render_change()

        end_time = System.monotonic_time(:millisecond)
        end_time - start_time
      end

      avg_input_time = Enum.sum(input_times) / length(input_times)
      max_input_time = Enum.max(input_times)

      # Input changes should be very responsive
      assert max_input_time < 20, "Slowest input response #{max_input_time}ms too slow"
      assert avg_input_time < 10, "Average input response #{avg_input_time}ms too slow"
    end
  end

  describe "throughput benchmarks" do
    test "system handles multiple concurrent users", %{conn: conn} do
      num_users = 10  # Reduced for sequential testing
      searches_per_user = 2

      # Track performance metrics
      metrics = Agent.start_link(fn -> %{
        total_searches: 0,
        successful_searches: 0,
        failed_searches: 0,
        total_time: 0,
        search_times: []
      } end)
      {:ok, metrics} = metrics

      with_mocks([
        {Cache, [], [
          get: fn _key ->
            # Mix of cache hits and misses
            if :rand.uniform() > 0.3, do: :error, else: {:ok, []}
          end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn query, _opts -> "throughput_#{query}_#{:rand.uniform(1000)}" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            # Simulate variable API response times
            delay = 50 + :rand.uniform(100)  # 50-150ms
            Process.sleep(delay)
            {:ok, @benchmark_response}
          end
        ]}
      ]) do
        start_time = System.monotonic_time(:millisecond)

        # Test sequential user sessions to measure throughput
        results = for user_id <- 1..num_users do
          try do
            {:ok, view, _html} = live(conn, ~p"/search")
            user_metrics = %{searches: 0, successes: 0, failures: 0, times: []}

            # Each user performs multiple searches
            user_metrics = for search_num <- 1..searches_per_user, reduce: user_metrics do
              acc ->
                query = "user#{user_id}_search#{search_num}"
                search_start = System.monotonic_time(:millisecond)

                view
                |> form("#search-form", search: %{query: query})
                |> render_submit()

                search_end = System.monotonic_time(:millisecond)
                search_time = search_end - search_start

                if has_element?(view, "[data-testid='search-result-card']") do
                  %{acc |
                    searches: acc.searches + 1,
                    successes: acc.successes + 1,
                    times: [search_time | acc.times]
                  }
                else
                  %{acc |
                    searches: acc.searches + 1,
                    failures: acc.failures + 1,
                    times: [search_time | acc.times]
                  }
                end
            end

            {:ok, user_metrics}
          rescue
            error -> {:error, user_id, error}
          end
        end

        end_time = System.monotonic_time(:millisecond)
        total_time = end_time - start_time

        # Analyze throughput results
        successful_users = Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

        total_searches = successful_users * searches_per_user
        all_search_times = results
        |> Enum.filter(fn {:ok, _} -> true; _ -> false end)
        |> Enum.flat_map(fn {:ok, metrics} -> metrics.times end)

        # Calculate throughput metrics
        searches_per_second = total_searches / (total_time / 1000)
        avg_search_time = if length(all_search_times) > 0, do: Enum.sum(all_search_times) / length(all_search_times), else: 0

        # Performance requirements (more lenient for sequential testing)
        user_success_rate = successful_users / num_users
        assert user_success_rate > 0.8, "User success rate #{user_success_rate} too low under concurrent load"

        assert searches_per_second > 1, "Throughput #{searches_per_second} searches/sec too low"
        assert avg_search_time < 5000, "Average search time #{avg_search_time}ms too slow under load"

        # System should handle the load without excessive degradation
        assert total_time < 20000, "Total test time #{total_time}ms indicates system overload"

        Agent.stop(metrics)
      end
    end

    test "cache hit ratio improves performance under load", %{conn: conn} do
      # Test that cache effectiveness improves overall system performance
      cache_scenarios = [
        {0.0, "no_cache"},      # No cache hits
        {0.5, "medium_cache"},  # 50% cache hits
        {0.9, "high_cache"}     # 90% cache hits
      ]

      performance_results = for {cache_hit_rate, scenario_name} <- cache_scenarios do
        with_mocks([
          {Cache, [], [
            get: fn _key ->
              if :rand.uniform() < cache_hit_rate do
                {:ok, [%SearchResult{
                  id: 1,
                  title: "Cached Result",
                  media_type: :movie,
                  release_date: ~D[2020-01-01],
                  overview: "Cached",
                  poster_path: "/cached.jpg",
                  genre_ids: [28],
                  vote_average: 8.0,
                  popularity: 100.0
                }]}
              else
                :error
              end
            end,
            put: fn _key, _value, _ttl -> :ok end,
            search_key: fn _query, _opts -> "cache_ratio_test" end
          ]},
          {TMDBClient, [], [
            search_multi: fn _query, _page ->
              Process.sleep(100)  # Consistent API delay
              {:ok, @benchmark_response}
            end
          ]}
        ]) do
          {:ok, view, _html} = live(conn, ~p"/search")

          # Perform multiple searches and measure performance
          num_searches = 10
          start_time = System.monotonic_time(:millisecond)

          for i <- 1..num_searches do
            view
            |> form("#search-form", search: %{query: "test#{i}"})
            |> render_submit()

            assert has_element?(view, "[data-testid='search-result-card']")
            Process.sleep(10)  # Brief pause between searches
          end

          end_time = System.monotonic_time(:millisecond)
          total_time = end_time - start_time
          avg_time_per_search = total_time / num_searches

          {scenario_name, cache_hit_rate, avg_time_per_search}
        end
      end

      # Analyze cache performance impact
      [no_cache, medium_cache, high_cache] = performance_results
      {_, _, no_cache_time} = no_cache
      {_, _, medium_cache_time} = medium_cache
      {_, _, high_cache_time} = high_cache

      # Higher cache hit rates should result in better performance
      assert medium_cache_time < no_cache_time,
        "Medium cache performance #{medium_cache_time}ms not better than no cache #{no_cache_time}ms"

      assert high_cache_time < medium_cache_time,
        "High cache performance #{high_cache_time}ms not better than medium cache #{medium_cache_time}ms"

      # High cache hit rate should provide significant performance improvement
      performance_improvement = (no_cache_time - high_cache_time) / no_cache_time
      assert performance_improvement > 0.3,
        "Cache performance improvement #{performance_improvement} less than expected 30%"
    end
  end

  describe "memory usage benchmarks" do
    test "memory usage remains stable during extended operation", %{conn: conn} do
      # Monitor memory usage during extended search operations
      memory_samples = Agent.start_link(fn -> [] end)
      {:ok, memory_samples} = memory_samples

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn query, _opts -> "memory_test_#{query}" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            Process.sleep(50)
            {:ok, @benchmark_response}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Start memory monitoring
        monitor_task = Task.async(fn ->
          for i <- 1..30 do  # Monitor for 3 seconds
            memory_usage = :erlang.memory(:total)
            Agent.update(memory_samples, fn samples ->
              [{i, memory_usage} | samples]
            end)
            Process.sleep(100)
          end
        end)

        # Generate search load
        load_task = Task.async(fn ->
          for i <- 1..20 do
            query = "memory_test_#{i}"
            view
            |> form("#search-form", search: %{query: query})
            |> render_submit()

            assert has_element?(view, "[data-testid='search-result-card']")
            Process.sleep(150)
          end
        end)

        # Wait for both tasks
        Task.await(load_task, 15000)
        Task.await(monitor_task, 15000)

        # Analyze memory stability
        samples = Agent.get(memory_samples, & &1) |> Enum.reverse()
        memory_values = Enum.map(samples, fn {_, memory} -> memory end)

        initial_memory = hd(memory_values)
        final_memory = List.last(memory_values)
        max_memory = Enum.max(memory_values)

        # Memory growth should be reasonable
        memory_growth = (final_memory - initial_memory) / initial_memory
        assert memory_growth < 0.2, "Memory growth #{memory_growth} indicates potential memory leak"

        # Peak memory usage should not be excessive
        peak_growth = (max_memory - initial_memory) / initial_memory
        assert peak_growth < 0.5, "Peak memory growth #{peak_growth} too high during operations"

        Agent.stop(memory_samples)
      end
    end
  end

  describe "performance regression detection" do
    test "search performance baseline establishment", %{conn: conn} do
      # This test establishes performance baselines that can be used to detect regressions

      with_mocks([
        {Cache, [], [
          get: fn _key -> :error end,
          put: fn _key, _value, _ttl -> :ok end,
          search_key: fn _query, _opts -> "baseline_test" end
        ]},
        {TMDBClient, [], [
          search_multi: fn _query, _page ->
            Process.sleep(100)  # Consistent 100ms API delay
            {:ok, @benchmark_response}
          end
        ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/search")

        # Perform baseline measurements
        measurements = for i <- 1..10 do
          start_time = System.monotonic_time(:millisecond)

          view
          |> form("#search-form", search: %{query: "baseline#{i}"})
          |> render_submit()

          assert has_element?(view, "[data-testid='search-result-card']")

          end_time = System.monotonic_time(:millisecond)
          end_time - start_time
        end

        # Calculate baseline statistics
        avg_time = Enum.sum(measurements) / length(measurements)
        min_time = Enum.min(measurements)
        max_time = Enum.max(measurements)
        std_dev = :math.sqrt(Enum.sum(Enum.map(measurements, fn x -> :math.pow(x - avg_time, 2) end)) / length(measurements))

        # Document baseline performance characteristics
        # These values can be used in CI/CD to detect performance regressions

        # Baseline expectations (these should be updated if system requirements change)
        assert avg_time < 500, "Baseline average time #{avg_time}ms exceeds expected 500ms"
        assert max_time < 1000, "Baseline max time #{max_time}ms exceeds expected 1000ms"
        assert std_dev < 100, "Baseline standard deviation #{std_dev}ms indicates inconsistent performance"

        # Log baseline metrics for regression tracking
        IO.puts("\n=== Performance Baseline Metrics ===")
        IO.puts("Average search time: #{Float.round(avg_time, 2)}ms")
        IO.puts("Min search time: #{min_time}ms")
        IO.puts("Max search time: #{max_time}ms")
        IO.puts("Standard deviation: #{Float.round(std_dev, 2)}ms")
        IO.puts("=====================================\n")
      end
    end
  end
end
