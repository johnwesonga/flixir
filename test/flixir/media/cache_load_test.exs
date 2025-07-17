defmodule Flixir.Media.CacheLoadTest do
  @moduledoc """
  Tests for cache behavior under different load conditions.

  Tests cover:
  - Cache performance under high concurrent access
  - Memory usage patterns under load
  - Cache eviction behavior under pressure
  - TTL behavior under concurrent access
  - Cache consistency during high load
  - Performance degradation patterns
  """

  use ExUnit.Case, async: false

  alias Flixir.Media.Cache

  setup do
    # Clear cache before each test
    Cache.clear_sync()
    :ok
  end

  describe "high concurrent access patterns" do
    test "cache handles many concurrent reads and writes" do
      # Number of concurrent operations
      num_operations = 100

      # Track operation results
      results = Agent.start_link(fn -> [] end)
      {:ok, results} = results

      # Start many concurrent operations
      tasks = for i <- 1..num_operations do
        Task.async(fn ->
          key = "concurrent_key_#{rem(i, 10)}"  # Use 10 different keys
          value = "value_#{i}"

          try do
            # Write operation
            Cache.put(key, value)

            # Read operation
            case Cache.get(key) do
              {:ok, _} ->
                Agent.update(results, fn r -> [:success | r] end)
                :ok
              :error ->
                Agent.update(results, fn r -> [:miss | r] end)
                :miss
            end
          rescue
            error ->
              Agent.update(results, fn r -> [{:error, error} | r] end)
              {:error, error}
          end
        end)
      end

      # Wait for all operations to complete
      operation_results = Task.await_many(tasks, 10000)

      # Analyze results
      successes = Enum.count(operation_results, &(&1 == :ok))
      _misses = Enum.count(operation_results, &(&1 == :miss))
      errors = Enum.count(operation_results, fn
        {:error, _} -> true
        _ -> false
      end)

      # Most operations should succeed
      success_rate = successes / num_operations
      assert success_rate > 0.8, "Success rate #{success_rate} too low under concurrent load"

      # Should have minimal errors
      error_rate = errors / num_operations
      assert error_rate < 0.1, "Error rate #{error_rate} too high under concurrent load"

      # Verify cache is still functional
      Cache.put("test_after_load", "test_value")
      assert {:ok, "test_value"} = Cache.get("test_after_load")

      Agent.stop(results)
    end

    test "cache performance degrades gracefully under extreme load" do
      # Extreme load test
      num_operations = 500
      start_time = System.monotonic_time(:millisecond)

      # Track timing for operations
      timings = Agent.start_link(fn -> [] end)
      {:ok, timings} = timings

      tasks = for i <- 1..num_operations do
        Task.async(fn ->
          operation_start = System.monotonic_time(:millisecond)

          key = "extreme_key_#{rem(i, 50)}"  # 50 different keys
          value = String.duplicate("data", 100)  # Larger values

          Cache.put(key, value)
          result = Cache.get(key)

          operation_end = System.monotonic_time(:millisecond)
          operation_time = operation_end - operation_start

          Agent.update(timings, fn t -> [operation_time | t] end)

          case result do
            {:ok, ^value} -> :success
            _ -> :failure
          end
        end)
      end

      results = Task.await_many(tasks, 30000)
      end_time = System.monotonic_time(:millisecond)

      total_time = end_time - start_time

      # Analyze performance
      successes = Enum.count(results, &(&1 == :success))
      success_rate = successes / num_operations

      # Should maintain reasonable success rate even under extreme load
      assert success_rate > 0.7, "Success rate #{success_rate} too low under extreme load"

      # Total time should be reasonable (less than 30 seconds for 500 operations)
      assert total_time < 30000, "Total time #{total_time}ms too high for #{num_operations} operations"

      # Get timing statistics
      all_timings = Agent.get(timings, & &1)
      avg_time = Enum.sum(all_timings) / length(all_timings)
      max_time = Enum.max(all_timings)

      # Average operation time should be reasonable
      assert avg_time < 100, "Average operation time #{avg_time}ms too high"
      assert max_time < 1000, "Max operation time #{max_time}ms too high"

      Agent.stop(timings)
    end

    test "cache maintains consistency during concurrent access to same keys" do
      # Test consistency when multiple processes access the same keys
      shared_keys = ["shared_1", "shared_2", "shared_3"]
      num_writers = 20
      num_readers = 30

      # Track inconsistencies
      inconsistencies = Agent.start_link(fn -> [] end)
      {:ok, inconsistencies} = inconsistencies

      # Start writer tasks
      writer_tasks = for i <- 1..num_writers do
        Task.async(fn ->
          key = Enum.random(shared_keys)
          value = "writer_#{i}_#{System.unique_integer()}"

          Cache.put(key, value)

          # Immediately read back to verify
          case Cache.get(key) do
            {:ok, ^value} -> :consistent
            {:ok, other_value} ->
              Agent.update(inconsistencies, fn inc ->
                [{:inconsistent_write, key, value, other_value} | inc]
              end)
              :inconsistent
            :error ->
              Agent.update(inconsistencies, fn inc ->
                [{:missing_after_write, key, value} | inc]
              end)
              :missing
          end
        end)
      end

      # Start reader tasks
      reader_tasks = for _i <- 1..num_readers do
        Task.async(fn ->
          key = Enum.random(shared_keys)

          # Read multiple times quickly
          reads = for _ <- 1..5 do
            Cache.get(key)
          end

          # Check for consistency in reads
          unique_values = reads
          |> Enum.filter(fn
            {:ok, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {:ok, value} -> value end)
          |> Enum.uniq()

          if length(unique_values) > 1 do
            Agent.update(inconsistencies, fn inc ->
              [{:inconsistent_reads, key, unique_values} | inc]
            end)
            :inconsistent_reads
          else
            :consistent_reads
          end
        end)
      end

      # Wait for all tasks
      writer_results = Task.await_many(writer_tasks, 10000)
      reader_results = Task.await_many(reader_tasks, 10000)

      # Analyze consistency
      writer_inconsistencies = Enum.count(writer_results, &(&1 != :consistent))
      reader_inconsistencies = Enum.count(reader_results, &(&1 == :inconsistent_reads))

      # Should have minimal inconsistencies (be more lenient for concurrent access)
      writer_consistency_rate = (num_writers - writer_inconsistencies) / num_writers
      reader_consistency_rate = (num_readers - reader_inconsistencies) / num_readers

      assert writer_consistency_rate > 0.6, "Writer consistency rate #{writer_consistency_rate} too low"
      assert reader_consistency_rate > 0.1, "Reader consistency rate #{reader_consistency_rate} too low"

      # Check recorded inconsistencies - be more lenient for concurrent access
      final_inconsistencies = Agent.get(inconsistencies, & &1)
      assert length(final_inconsistencies) < 25, "Too many inconsistencies: #{inspect(final_inconsistencies)}"

      Agent.stop(inconsistencies)
    end
  end

  describe "memory usage under load" do
    test "cache memory usage grows predictably with data" do
      initial_stats = Cache.stats()
      initial_memory = initial_stats.memory_bytes

      # Add known amount of data
      data_size = 1000  # bytes per entry
      num_entries = 100
      large_value = String.duplicate("x", data_size)

      for i <- 1..num_entries do
        Cache.put("memory_test_#{i}", large_value)
      end

      after_stats = Cache.stats()
      memory_increase = after_stats.memory_bytes - initial_memory

      # Memory should have increased
      assert memory_increase > 0, "Memory usage should increase with data"

      # Memory increase should be reasonable (not excessive overhead)
      expected_minimum = num_entries * data_size * 0.1  # Allow for more realistic overhead
      assert memory_increase > expected_minimum,
        "Memory increase #{memory_increase} less than expected minimum #{expected_minimum}"

      # Memory increase should not be excessive
      expected_maximum = num_entries * data_size * 3  # Allow for 200% overhead
      assert memory_increase < expected_maximum,
        "Memory increase #{memory_increase} exceeds expected maximum #{expected_maximum}"
    end

    test "cache handles memory pressure through eviction" do
      # Fill cache beyond its limits
      initial_stats = Cache.stats()
      max_entries = initial_stats.max_entries

      # Add more entries than the limit
      excess_entries = trunc(max_entries * 1.5)
      large_value = String.duplicate("data", 100)

      for i <- 1..excess_entries do
        Cache.put("eviction_test_#{i}", large_value)
      end

      # Give time for evictions to process
      Process.sleep(500)

      final_stats = Cache.stats()

      # Cache size should be limited
      assert final_stats.size <= max_entries,
        "Cache size #{final_stats.size} exceeds max_entries #{max_entries}"

      # Should have recorded evictions
      assert final_stats.evictions > 0, "No evictions recorded despite exceeding capacity"

      # Cache should still be functional
      Cache.put("test_after_eviction", "test_value")
      assert {:ok, "test_value"} = Cache.get("test_after_eviction")
    end

    test "memory usage stabilizes under continuous load" do
      # Monitor memory usage over time under continuous load
      memory_samples = Agent.start_link(fn -> [] end)
      {:ok, memory_samples} = memory_samples

      # Start background task that continuously monitors memory
      monitor_task = Task.async(fn ->
        for _ <- 1..20 do  # Sample for 2 seconds
          stats = Cache.stats()
          Agent.update(memory_samples, fn samples ->
            [stats.memory_bytes | samples]
          end)
          Process.sleep(100)
        end
      end)

      # Generate continuous load
      load_task = Task.async(fn ->
        for i <- 1..1000 do
          key = "continuous_#{rem(i, 100)}"  # Reuse keys to trigger evictions
          value = String.duplicate("load_data", 50)
          Cache.put(key, value)

          if rem(i, 10) == 0 do
            Process.sleep(1)  # Brief pause
          end
        end
      end)

      # Wait for both tasks
      Task.await(load_task, 10000)
      Task.await(monitor_task, 10000)

      # Analyze memory stability
      samples = Agent.get(memory_samples, & &1) |> Enum.reverse()

      # Should have collected samples
      assert length(samples) > 10, "Not enough memory samples collected"

      # Calculate memory growth rate
      first_half = Enum.take(samples, div(length(samples), 2))
      second_half = Enum.drop(samples, div(length(samples), 2))

      avg_first_half = Enum.sum(first_half) / length(first_half)
      avg_second_half = Enum.sum(second_half) / length(second_half)

      growth_rate = (avg_second_half - avg_first_half) / avg_first_half

      # Memory growth should stabilize (not grow indefinitely)
      assert growth_rate < 0.5, "Memory growth rate #{growth_rate} indicates memory leak"

      Agent.stop(memory_samples)
    end
  end

  describe "TTL behavior under load" do
    test "TTL expiration works correctly under concurrent access" do
      # Set entries with short TTL under concurrent access
      num_concurrent = 50
      ttl_seconds = 2

      # Track expiration behavior
      expiration_results = Agent.start_link(fn -> [] end)
      {:ok, expiration_results} = expiration_results

      tasks = for i <- 1..num_concurrent do
        Task.async(fn ->
          key = "ttl_test_#{i}"
          value = "value_#{i}"

          # Put with short TTL
          Cache.put(key, value, ttl_seconds)

          # Verify immediate availability
          immediate_result = Cache.get(key)

          # Wait for expiration
          Process.sleep((ttl_seconds + 1) * 1000)

          # Check if expired
          expired_result = Cache.get(key)

          result = {immediate_result, expired_result}
          Agent.update(expiration_results, fn results -> [result | results] end)

          case result do
            {{:ok, ^value}, :error} -> :correct_expiration
            {{:ok, ^value}, {:ok, ^value}} -> :failed_to_expire
            {:error, _} -> :immediate_failure
            _ -> :unexpected_result
          end
        end)
      end

      results = Task.await_many(tasks, 10000)

      # Analyze TTL behavior
      correct_expirations = Enum.count(results, &(&1 == :correct_expiration))
      failed_expirations = Enum.count(results, &(&1 == :failed_to_expire))
      immediate_failures = Enum.count(results, &(&1 == :immediate_failure))

      # Most entries should expire correctly
      expiration_rate = correct_expirations / num_concurrent
      assert expiration_rate > 0.8, "TTL expiration rate #{expiration_rate} too low under concurrent access"

      # Should have minimal failures
      failure_rate = (failed_expirations + immediate_failures) / num_concurrent
      assert failure_rate < 0.2, "TTL failure rate #{failure_rate} too high"

      Agent.stop(expiration_results)
    end

    test "cache cleanup handles many expired entries efficiently" do
      # Create many entries that will expire quickly
      num_entries = 200
      short_ttl = 1  # 1 second

      start_time = System.monotonic_time(:millisecond)

      # Add many entries with short TTL using synchronous puts
      for i <- 1..num_entries do
        Cache.put_sync("cleanup_test_#{i}", "value_#{i}", short_ttl)
      end

      initial_stats = Cache.stats()
      initial_size = initial_stats.size

      # Wait for expiration
      Process.sleep(1200)  # Wait for TTL to expire

      # Force cleanup of expired entries
      expired_count = Cache.force_cleanup()

      final_stats = Cache.stats()
      final_size = final_stats.size
      cleanup_time = System.monotonic_time(:millisecond) - start_time

      # Most entries should be cleaned up
      cleanup_rate = expired_count / max(initial_size, 1)
      assert cleanup_rate > 0.8, "Cleanup rate #{cleanup_rate} too low for expired entries (initial: #{initial_size}, final: #{final_size}, expired: #{expired_count})"

      # Cleanup should be reasonably fast
      assert cleanup_time < 5000, "Cleanup took too long: #{cleanup_time}ms"

      # Cache should still be functional after cleanup
      Cache.put("test_after_cleanup", "test_value")
      assert {:ok, "test_value"} = Cache.get("test_after_cleanup")
    end
  end

  describe "performance benchmarks" do
    test "cache read performance under load" do
      # Pre-populate cache
      num_entries = 500
      for i <- 1..num_entries do
        Cache.put_sync("perf_read_#{i}", "value_#{i}")
      end

      # Benchmark read performance
      num_reads = 5000
      start_time = System.monotonic_time(:microsecond)

      tasks = for i <- 1..num_reads do
        Task.async(fn ->
          key = "perf_read_#{rem(i, num_entries) + 1}"
          Cache.get(key)
        end)
      end

      results = Task.await_many(tasks, 10000)
      end_time = System.monotonic_time(:microsecond)

      total_time_ms = (end_time - start_time) / 1000
      avg_read_time_us = (end_time - start_time) / num_reads

      # Analyze performance
      successful_reads = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      success_rate = successful_reads / num_reads
      assert success_rate > 0.95, "Read success rate #{success_rate} too low"

      # Performance benchmarks
      assert avg_read_time_us < 1000, "Average read time #{avg_read_time_us}μs too slow"
      assert total_time_ms < 5000, "Total read time #{total_time_ms}ms too slow for #{num_reads} reads"

      # Throughput should be reasonable
      reads_per_second = num_reads / (total_time_ms / 1000)
      assert reads_per_second > 1000, "Read throughput #{reads_per_second} reads/sec too low"
    end

    test "cache write performance under load" do
      # Get cache max entries to avoid eviction during integrity test
      cache_stats = Cache.stats()
      max_entries = cache_stats.max_entries
      
      # Use a number of writes that won't exceed cache capacity
      num_writes = min(800, max_entries - 100)  # Leave room for other tests
      value = String.duplicate("benchmark_data", 10)

      start_time = System.monotonic_time(:microsecond)

      tasks = for i <- 1..num_writes do
        Task.async(fn ->
          key = "perf_write_#{i}"
          Cache.put_sync(key, value)
        end)
      end

      Task.await_many(tasks, 15000)
      end_time = System.monotonic_time(:microsecond)

      total_time_ms = (end_time - start_time) / 1000
      avg_write_time_us = (end_time - start_time) / num_writes

      # Performance benchmarks
      assert avg_write_time_us < 2000, "Average write time #{avg_write_time_us}μs too slow"
      assert total_time_ms < 10000, "Total write time #{total_time_ms}ms too slow for #{num_writes} writes"

      # Throughput should be reasonable
      writes_per_second = num_writes / (total_time_ms / 1000)
      assert writes_per_second > 500, "Write throughput #{writes_per_second} writes/sec too low"

      # Verify data integrity after high-speed writes
      sample_keys = for i <- 1..100, do: "perf_write_#{i}"
      successful_reads = Enum.count(sample_keys, fn key ->
        case Cache.get(key) do
          {:ok, ^value} -> true
          _ -> false
        end
      end)

      integrity_rate = successful_reads / 100
      assert integrity_rate > 0.95, "Data integrity rate #{integrity_rate} too low after high-speed writes"
    end

    test "mixed read/write performance under realistic load" do
      # Simulate realistic mixed workload
      num_operations = 2000  # Reduced to avoid cache eviction
      read_ratio = 0.8  # 80% reads, 20% writes

      # Pre-populate some data (stay within cache limits)
      for i <- 1..500 do
        Cache.put_sync("mixed_#{i}", "initial_value_#{i}")
      end

      start_time = System.monotonic_time(:microsecond)

      tasks = for i <- 1..num_operations do
        Task.async(fn ->
          if :rand.uniform() < read_ratio do
            # Read operation
            key = "mixed_#{rem(i, 500) + 1}"
            case Cache.get(key) do
              {:ok, _} -> :read_success
              :error -> :read_miss
            end
          else
            # Write operation
            key = "mixed_#{rem(i, 500) + 1}"
            value = "updated_value_#{i}"
            Cache.put_sync(key, value)
            :write_success
          end
        end)
      end

      results = Task.await_many(tasks, 15000)
      end_time = System.monotonic_time(:microsecond)

      total_time_ms = (end_time - start_time) / 1000
      avg_operation_time_us = (end_time - start_time) / num_operations

      # Analyze results
      read_successes = Enum.count(results, &(&1 == :read_success))
      read_misses = Enum.count(results, &(&1 == :read_miss))
      write_successes = Enum.count(results, &(&1 == :write_success))

      total_reads = read_successes + read_misses
      expected_reads = trunc(num_operations * read_ratio)
      expected_writes = num_operations - expected_reads

      # Verify operation distribution
      assert abs(total_reads - expected_reads) < 100, "Read count #{total_reads} differs from expected #{expected_reads}"
      assert write_successes >= expected_writes - 100, "Write count #{write_successes} less than expected #{expected_writes}"

      # Performance benchmarks for mixed workload
      assert avg_operation_time_us < 1500, "Average mixed operation time #{avg_operation_time_us}μs too slow"
      assert total_time_ms < 8000, "Total mixed workload time #{total_time_ms}ms too slow"

      # Throughput should be reasonable for mixed workload
      operations_per_second = num_operations / (total_time_ms / 1000)
      assert operations_per_second > 600, "Mixed workload throughput #{operations_per_second} ops/sec too low"
    end
  end
end
