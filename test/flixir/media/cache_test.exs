defmodule Flixir.Media.CacheTest do
  use ExUnit.Case, async: false

  alias Flixir.Media.Cache

  setup do
    # Clear cache before each test
    Cache.clear()

    :ok
  end

  describe "basic cache operations" do
    test "put and get operations work correctly" do
      key = "test_key"
      value = %{data: "test_value"}

      # Put value in cache
      Cache.put(key, value)

      # Get value from cache
      assert {:ok, ^value} = Cache.get(key)
    end

    test "get returns error for non-existent key" do
      assert :error = Cache.get("non_existent_key")
    end

    test "delete removes key from cache" do
      key = "test_key"
      value = %{data: "test_value"}

      Cache.put(key, value)
      assert {:ok, ^value} = Cache.get(key)

      Cache.delete(key)
      assert :error = Cache.get(key)
    end

    test "clear removes all entries from cache" do
      Cache.put("key1", "value1")
      Cache.put("key2", "value2")

      assert {:ok, "value1"} = Cache.get("key1")
      assert {:ok, "value2"} = Cache.get("key2")

      Cache.clear()

      assert :error = Cache.get("key1")
      assert :error = Cache.get("key2")
    end
  end

  describe "TTL functionality" do
    test "entries expire after TTL" do
      key = "expiring_key"
      value = "expiring_value"

      # Put with short TTL
      Cache.put(key, value, 1)

      # Should be available immediately
      assert {:ok, ^value} = Cache.get(key)

      # Wait for expiration
      Process.sleep(1100)

      # Should be expired now
      assert :error = Cache.get(key)
    end

    test "entries with longer TTL remain available" do
      key = "long_ttl_key"
      value = "long_ttl_value"

      # Put with longer TTL
      Cache.put(key, value, 10)

      # Should be available immediately
      assert {:ok, ^value} = Cache.get(key)

      # Wait a bit but not past expiration
      Process.sleep(500)

      # Should still be available
      assert {:ok, ^value} = Cache.get(key)
    end

    test "default TTL is used when not specified" do
      key = "default_ttl_key"
      value = "default_ttl_value"

      Cache.put(key, value)

      # Should be available immediately
      assert {:ok, ^value} = Cache.get(key)

      # Wait for default TTL (5 seconds in test config)
      Process.sleep(5100)

      # Should be expired now
      assert :error = Cache.get(key)
    end
  end

  describe "cache cleanup" do
    test "expired entries are cleaned up automatically" do
      # Put entries with short TTL
      Cache.put("cleanup1", "value1", 1)
      Cache.put("cleanup2", "value2", 1)

      # Verify they exist
      assert {:ok, "value1"} = Cache.get("cleanup1")
      assert {:ok, "value2"} = Cache.get("cleanup2")

      # Wait for expiration and cleanup cycle
      Process.sleep(2000)  # Wait for TTL + cleanup interval

      # Entries should be cleaned up
      assert :error = Cache.get("cleanup1")
      assert :error = Cache.get("cleanup2")
    end
  end

  describe "cache eviction" do
    test "cache handles max entries limit" do
      # This test verifies the eviction mechanism exists
      # We'll add many entries and verify the cache doesn't grow indefinitely

      _initial_stats = Cache.stats()

      # Add many entries
      for i <- 1..1500 do
        Cache.put("evict_key#{i}", "value#{i}")
      end

      # Give some time for evictions to process
      Process.sleep(100)

      final_stats = Cache.stats()

      # Cache size should be limited by max_entries
      assert final_stats.size <= final_stats.max_entries

      # Should have some evictions
      assert final_stats.evictions > 0
    end
  end

  describe "cache statistics" do
    test "stats returns correct cache information" do
      # Put some entries
      Cache.put("stats1", "value1")
      Cache.put("stats2", "value2")

      # Get some entries to generate hits
      Cache.get("stats1")
      Cache.get("stats1")  # Second hit

      # Try to get non-existent entry to generate miss
      Cache.get("non_existent")

      stats = Cache.stats()

      assert stats.size >= 2
      assert stats.hits >= 2
      assert stats.misses >= 1
      assert is_integer(stats.max_entries)
      assert is_integer(stats.ttl_seconds)
      assert is_integer(stats.memory_bytes)
      assert stats.memory_bytes > 0
    end
  end

  describe "search key generation" do
    test "search_key generates consistent keys for same parameters" do
      query = "batman"
      opts = [media_type: :movie, sort_by: :popularity, page: 1]

      key1 = Cache.search_key(query, opts)
      key2 = Cache.search_key(query, opts)

      assert key1 == key2
    end

    test "search_key generates different keys for different parameters" do
      query = "batman"

      key1 = Cache.search_key(query, [media_type: :movie])
      key2 = Cache.search_key(query, [media_type: :tv])
      key3 = Cache.search_key(query, [media_type: :movie, page: 2])

      assert key1 != key2
      assert key1 != key3
      assert key2 != key3
    end

    test "search_key normalizes query string" do
      key1 = Cache.search_key("  Batman  ", [])
      key2 = Cache.search_key("batman", [])
      key3 = Cache.search_key("BATMAN", [])

      # All should generate the same key due to normalization
      assert key1 == key2
      assert key2 == key3
    end

    test "search_key uses default values for missing options" do
      query = "batman"

      key1 = Cache.search_key(query, [])
      key2 = Cache.search_key(query, [media_type: :all, sort_by: :relevance, page: 1])

      assert key1 == key2
    end

    test "search_key includes all parameters in key" do
      query = "batman"
      opts = [media_type: :movie, sort_by: :popularity, page: 2]

      key = Cache.search_key(query, opts)

      assert String.contains?(key, "batman")
      assert String.contains?(key, "movie")
      assert String.contains?(key, "popularity")
      assert String.contains?(key, "2")
    end
  end

  describe "concurrent access" do
    test "cache handles concurrent reads and writes" do
      # Start multiple processes that read and write concurrently
      tasks = for i <- 1..10 do
        Task.async(fn ->
          key = "concurrent_key_#{i}"
          value = "concurrent_value_#{i}"

          # Write
          Cache.put(key, value)

          # Read
          case Cache.get(key) do
            {:ok, ^value} -> :ok
            _ -> :error
          end
        end)
      end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)

      # All operations should succeed
      assert Enum.all?(results, &(&1 == :ok))
    end
  end

  describe "memory management" do
    test "cache memory usage is tracked" do
      # Start with current cache state
      _initial_stats = Cache.stats()

      # Add some data
      large_value = String.duplicate("x", 1000)
      Cache.put("large_key", large_value)

      after_stats = Cache.stats()

      # Memory usage should be tracked (may not necessarily increase due to other operations)
      assert is_integer(after_stats.memory_bytes)
      assert after_stats.memory_bytes > 0
    end
  end

  describe "integration with search functionality" do
    test "cache can store and retrieve search results" do
      # Simulate search results
      search_results = [
        %{id: 1, title: "Batman", media_type: :movie},
        %{id: 2, title: "Batman Returns", media_type: :movie}
      ]

      query = "batman"
      opts = [media_type: :movie, sort_by: :popularity, page: 1]
      cache_key = Cache.search_key(query, opts)

      # Store search results
      Cache.put(cache_key, search_results)

      # Retrieve search results
      assert {:ok, ^search_results} = Cache.get(cache_key)
    end

    test "different search parameters create different cache entries" do
      results1 = [%{id: 1, title: "Batman", media_type: :movie}]
      results2 = [%{id: 2, title: "Batman", media_type: :tv}]

      key1 = Cache.search_key("batman", [media_type: :movie])
      key2 = Cache.search_key("batman", [media_type: :tv])

      Cache.put(key1, results1)
      Cache.put(key2, results2)

      assert {:ok, ^results1} = Cache.get(key1)
      assert {:ok, ^results2} = Cache.get(key2)
    end
  end
end
