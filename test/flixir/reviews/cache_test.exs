defmodule Flixir.Reviews.CacheTest do
  use ExUnit.Case, async: true

  alias Flixir.Reviews.Cache

  setup do
    # Clear cache before each test (Cache is already started by the application)
    Cache.clear_all()

    :ok
  end

  describe "basic cache operations" do
    test "put/3 and get/1 work correctly" do
      key = "test_key"
      data = %{test: "data"}

      assert Cache.put(key, data) == :ok
      assert Cache.get(key) == {:ok, data}
    end

    test "get/1 returns :error for non-existent key" do
      assert Cache.get("non_existent_key") == :error
    end

    test "put/3 overwrites existing data" do
      key = "test_key"
      original_data = %{test: "original"}
      new_data = %{test: "new"}

      Cache.put(key, original_data)
      Cache.put(key, new_data)

      assert Cache.get(key) == {:ok, new_data}
    end
  end

  describe "TTL expiration" do
    test "data expires after TTL" do
      key = "expiring_key"
      data = %{test: "data"}
      short_ttl = 50  # 50 milliseconds

      Cache.put(key, data, short_ttl)
      assert Cache.get(key) == {:ok, data}

      # Wait for expiration
      Process.sleep(60)

      assert Cache.get(key) == :error
    end

    test "data is accessible before TTL expires" do
      key = "valid_key"
      data = %{test: "data"}
      long_ttl = 5000  # 5 seconds

      Cache.put(key, data, long_ttl)

      # Should still be accessible
      Process.sleep(100)
      assert Cache.get(key) == {:ok, data}
    end

    test "expired entries are cleaned up on access" do
      key = "cleanup_key"
      data = %{test: "data"}
      short_ttl = 50

      Cache.put(key, data, short_ttl)
      Process.sleep(60)

      # This should trigger cleanup of expired entry
      assert Cache.get(key) == :error

      # Verify entry is actually removed from ETS table
      assert :ets.lookup(:reviews_cache, key) == []
    end
  end

  describe "cache key generation" do
    test "reviews_cache_key/3 generates correct key without filters" do
      key = Cache.reviews_cache_key("movie", "123")
      assert key == "reviews:movie:123:"
    end

    test "reviews_cache_key/3 generates correct key with filters" do
      filters = %{sort: "date", rating: "positive"}
      key = Cache.reviews_cache_key("tv", "456", filters)

      # Filters should be sorted alphabetically
      assert key == "reviews:tv:456:rating:positive,sort:date"
    end

    test "reviews_cache_key/3 handles empty filters map" do
      key = Cache.reviews_cache_key("movie", "789", %{})
      assert key == "reviews:movie:789:"
    end

    test "ratings_cache_key/2 generates correct key" do
      key = Cache.ratings_cache_key("movie", "123")
      assert key == "ratings:movie:123"
    end
  end

  describe "reviews-specific cache operations" do
    test "put_reviews/4 and get_reviews/3 work correctly" do
      reviews = [%{id: 1, content: "Great movie!"}]
      filters = %{sort: "date"}

      assert Cache.put_reviews("movie", "123", reviews, filters) == :ok
      assert Cache.get_reviews("movie", "123", filters) == {:ok, reviews}
    end

    test "get_reviews/3 returns :error for non-existent reviews" do
      assert Cache.get_reviews("movie", "999") == :error
    end

    test "reviews cache uses 1-hour TTL by default" do
      reviews = [%{id: 1, content: "Test review"}]
      Cache.put_reviews("movie", "123", reviews)

      # Should still be accessible after a short time
      Process.sleep(100)
      assert Cache.get_reviews("movie", "123") == {:ok, reviews}
    end

    test "different filter combinations create different cache entries" do
      reviews1 = [%{id: 1, content: "Review 1"}]
      reviews2 = [%{id: 2, content: "Review 2"}]

      Cache.put_reviews("movie", "123", reviews1, %{sort: "date"})
      Cache.put_reviews("movie", "123", reviews2, %{sort: "rating"})

      assert Cache.get_reviews("movie", "123", %{sort: "date"}) == {:ok, reviews1}
      assert Cache.get_reviews("movie", "123", %{sort: "rating"}) == {:ok, reviews2}
    end
  end

  describe "ratings-specific cache operations" do
    test "put_ratings/3 and get_ratings/2 work correctly" do
      ratings = %{average: 8.5, total: 100}

      assert Cache.put_ratings("movie", "123", ratings) == :ok
      assert Cache.get_ratings("movie", "123") == {:ok, ratings}
    end

    test "get_ratings/2 returns :error for non-existent ratings" do
      assert Cache.get_ratings("tv", "999") == :error
    end

    test "ratings cache uses 30-minute TTL by default" do
      ratings = %{average: 7.2, total: 50}
      Cache.put_ratings("tv", "456", ratings)

      # Should still be accessible after a short time
      Process.sleep(100)
      assert Cache.get_ratings("tv", "456") == {:ok, ratings}
    end
  end

  describe "cache management" do
    test "clear_all/0 removes all cached data" do
      Cache.put("key1", "data1")
      Cache.put("key2", "data2")
      Cache.put_reviews("movie", "123", [])
      Cache.put_ratings("tv", "456", %{})

      assert Cache.get("key1") == {:ok, "data1"}
      assert Cache.get("key2") == {:ok, "data2"}

      Cache.clear_all()

      assert Cache.get("key1") == :error
      assert Cache.get("key2") == :error
      assert Cache.get_reviews("movie", "123") == :error
      assert Cache.get_ratings("tv", "456") == :error
    end

    test "cleanup_expired/0 removes only expired entries" do
      valid_key = "valid_key"
      expired_key = "expired_key"

      # Put data with different TTLs
      Cache.put(valid_key, "valid_data", 5000)  # 5 seconds
      Cache.put(expired_key, "expired_data", 50)  # 50 milliseconds

      # Wait for one to expire
      Process.sleep(60)

      # Both should be in cache before cleanup
      assert :ets.lookup(:reviews_cache, valid_key) != []
      assert :ets.lookup(:reviews_cache, expired_key) != []

      # Cleanup expired entries
      Cache.cleanup_expired()

      # Valid entry should remain, expired should be gone
      assert Cache.get(valid_key) == {:ok, "valid_data"}
      assert :ets.lookup(:reviews_cache, expired_key) == []
    end
  end

  describe "concurrent access" do
    test "cache handles concurrent reads and writes" do
      key = "concurrent_key"

      # Start multiple processes that read and write concurrently
      tasks = for i <- 1..10 do
        Task.async(fn ->
          data = %{process: i, timestamp: System.system_time()}
          Cache.put("#{key}_#{i}", data)
          Cache.get("#{key}_#{i}")
        end)
      end

      results = Task.await_many(tasks)

      # All operations should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)
    end

    test "cache handles concurrent access to same key" do
      key = "shared_key"
      initial_data = %{value: "initial"}

      Cache.put(key, initial_data)

      # Multiple processes reading the same key
      tasks = for _i <- 1..5 do
        Task.async(fn -> Cache.get(key) end)
      end

      results = Task.await_many(tasks)

      # All should return the same data
      assert Enum.all?(results, &(&1 == {:ok, initial_data}))
    end
  end

  describe "edge cases" do
    test "handles nil data" do
      key = "nil_key"

      assert Cache.put(key, nil) == :ok
      assert Cache.get(key) == {:ok, nil}
    end

    test "handles empty collections" do
      empty_list_key = "empty_list"
      empty_map_key = "empty_map"

      Cache.put(empty_list_key, [])
      Cache.put(empty_map_key, %{})

      assert Cache.get(empty_list_key) == {:ok, []}
      assert Cache.get(empty_map_key) == {:ok, %{}}
    end

    test "handles large data structures" do
      large_data = for i <- 1..1000, do: %{id: i, content: "Content #{i}"}
      key = "large_data"

      assert Cache.put(key, large_data) == :ok
      assert Cache.get(key) == {:ok, large_data}
    end

    test "handles special characters in keys" do
      special_key = "key:with/special\\chars"
      data = %{test: "data"}

      assert Cache.put(special_key, data) == :ok
      assert Cache.get(special_key) == {:ok, data}
    end
  end
end
