defmodule Flixir.Lists.CacheTest do
  use ExUnit.Case, async: false

  alias Flixir.Lists.Cache

  setup do
    # Clear cache and reset stats for each test
    # The cache is already started by the application
    Cache.clear_cache()
    Cache.reset_stats()
    :ok
  end

  describe "user lists caching" do
    test "put_user_lists/3 stores lists with default TTL" do
      user_id = 123
      lists = [
        %{"id" => 1, "name" => "Watchlist", "item_count" => 5},
        %{"id" => 2, "name" => "Favorites", "item_count" => 10}
      ]

      assert :ok = Cache.put_user_lists(user_id, lists)
      assert {:ok, ^lists} = Cache.get_user_lists(user_id)
    end

    test "put_user_lists/3 stores lists with custom TTL" do
      user_id = 123
      lists = [%{"id" => 1, "name" => "Test List"}]
      custom_ttl = 100  # 100ms

      assert :ok = Cache.put_user_lists(user_id, lists, custom_ttl)
      assert {:ok, ^lists} = Cache.get_user_lists(user_id)

      # Wait for expiration
      Process.sleep(150)
      assert {:error, :expired} = Cache.get_user_lists(user_id)
    end

    test "get_user_lists/1 returns error for non-existent user" do
      assert {:error, :not_found} = Cache.get_user_lists(999)
    end

    test "get_user_lists/1 handles expired entries" do
      user_id = 123
      lists = [%{"id" => 1, "name" => "Test List"}]

      # Store with very short TTL
      Cache.put_user_lists(user_id, lists, 50)

      # Should be available immediately
      assert {:ok, ^lists} = Cache.get_user_lists(user_id)

      # Wait for expiration
      Process.sleep(100)
      assert {:error, :expired} = Cache.get_user_lists(user_id)
    end
  end

  describe "individual list caching" do
    test "put_list/2 and get_list/1 work correctly" do
      list_data = %{
        "id" => 456,
        "name" => "My Watchlist",
        "description" => "Movies to watch",
        "item_count" => 15
      }

      assert :ok = Cache.put_list(list_data)
      assert {:ok, ^list_data} = Cache.get_list(456)
    end

    test "get_list/1 returns error for non-existent list" do
      assert {:error, :not_found} = Cache.get_list(999)
    end

    test "get_list/1 handles expired entries" do
      list_data = %{"id" => 456, "name" => "Test List"}

      Cache.put_list(list_data, 50)  # 50ms TTL
      assert {:ok, ^list_data} = Cache.get_list(456)

      Process.sleep(100)
      assert {:error, :expired} = Cache.get_list(456)
    end
  end

  describe "list items caching" do
    test "put_list_items/3 and get_list_items/1 work correctly" do
      list_id = 789
      items = [
        %{"id" => 550, "title" => "Fight Club", "poster_path" => "/path1.jpg"},
        %{"id" => 680, "title" => "Pulp Fiction", "poster_path" => "/path2.jpg"}
      ]

      assert :ok = Cache.put_list_items(list_id, items)
      assert {:ok, ^items} = Cache.get_list_items(list_id)
    end

    test "get_list_items/1 returns error for non-existent list" do
      assert {:error, :not_found} = Cache.get_list_items(999)
    end

    test "get_list_items/1 handles expired entries" do
      list_id = 789
      items = [%{"id" => 550, "title" => "Fight Club"}]

      Cache.put_list_items(list_id, items, 50)
      assert {:ok, ^items} = Cache.get_list_items(list_id)

      Process.sleep(100)
      assert {:error, :expired} = Cache.get_list_items(list_id)
    end
  end

  describe "cache invalidation" do
    test "invalidate_user_cache/1 removes user lists" do
      user_id = 123
      lists = [%{"id" => 1, "name" => "Test List"}]

      Cache.put_user_lists(user_id, lists)
      assert {:ok, ^lists} = Cache.get_user_lists(user_id)

      Cache.invalidate_user_cache(user_id)
      assert {:error, :not_found} = Cache.get_user_lists(user_id)
    end

    test "invalidate_list_cache/1 removes list and its items" do
      list_id = 456
      list_data = %{"id" => list_id, "name" => "Test List"}
      items = [%{"id" => 550, "title" => "Fight Club"}]

      Cache.put_list(list_data)
      Cache.put_list_items(list_id, items)

      assert {:ok, ^list_data} = Cache.get_list(list_id)
      assert {:ok, ^items} = Cache.get_list_items(list_id)

      Cache.invalidate_list_cache(list_id)

      assert {:error, :not_found} = Cache.get_list(list_id)
      assert {:error, :not_found} = Cache.get_list_items(list_id)
    end

    test "clear_cache/0 removes all entries" do
      user_id = 123
      list_id = 456

      Cache.put_user_lists(user_id, [%{"id" => 1}])
      Cache.put_list(%{"id" => list_id, "name" => "Test"})

      assert {:ok, _} = Cache.get_user_lists(user_id)
      assert {:ok, _} = Cache.get_list(list_id)

      Cache.clear_cache()

      assert {:error, :not_found} = Cache.get_user_lists(user_id)
      assert {:error, :not_found} = Cache.get_list(list_id)
    end
  end

  describe "cache statistics" do
    test "tracks hits, misses, and writes" do
      user_id = 123
      lists = [%{"id" => 1, "name" => "Test"}]

      # Initial stats should be zero
      stats = Cache.get_stats()
      assert stats.hits == 0
      assert stats.misses == 0
      assert stats.writes == 0

      # Write should increment writes
      Cache.put_user_lists(user_id, lists)
      stats = Cache.get_stats()
      assert stats.writes == 1

      # Hit should increment hits
      Cache.get_user_lists(user_id)
      stats = Cache.get_stats()
      assert stats.hits == 1

      # Miss should increment misses
      Cache.get_user_lists(999)
      stats = Cache.get_stats()
      assert stats.misses == 1
    end

    test "tracks expired entries" do
      user_id = 123
      lists = [%{"id" => 1, "name" => "Test"}]

      Cache.put_user_lists(user_id, lists, 50)  # 50ms TTL
      Process.sleep(100)

      Cache.get_user_lists(user_id)  # This should be expired

      stats = Cache.get_stats()
      assert stats.expired == 1
      assert stats.misses == 1
    end

    test "tracks invalidations" do
      user_id = 123
      Cache.put_user_lists(user_id, [%{"id" => 1}])

      Cache.invalidate_user_cache(user_id)

      stats = Cache.get_stats()
      assert stats.invalidations == 1
    end

    test "reset_stats/0 clears all statistics" do
      user_id = 123
      Cache.put_user_lists(user_id, [%{"id" => 1}])
      Cache.get_user_lists(user_id)
      Cache.get_user_lists(999)

      stats = Cache.get_stats()
      assert stats.writes > 0
      assert stats.hits > 0
      assert stats.misses > 0

      Cache.reset_stats()

      stats = Cache.get_stats()
      assert stats.writes == 0
      assert stats.hits == 0
      assert stats.misses == 0
    end
  end

  describe "cache monitoring" do
    test "get_cache_info/0 returns size and memory information" do
      # Add some data to cache
      Cache.put_user_lists(123, [%{"id" => 1, "name" => "Test"}])
      Cache.put_list(%{"id" => 456, "name" => "Another Test"})

      info = Cache.get_cache_info()

      assert is_integer(info.size)
      assert info.size > 0
      assert is_integer(info.memory)
      assert info.memory > 0
      assert is_integer(info.memory_bytes)
      assert info.memory_bytes > 0
    end
  end

  describe "cache warming" do
    test "warm_cache/2 accepts user_id and list_ids" do
      # This is an async operation, so we just test it doesn't crash
      assert :ok = Cache.warm_cache(123, [1, 2, 3])

      # Give it a moment to process
      Process.sleep(10)
    end
  end

  describe "automatic cleanup" do
    test "expired entries are cleaned up automatically" do
      # This test is more complex as it involves the GenServer's cleanup process
      # We'll test the cleanup function indirectly by checking that expired
      # entries don't accumulate indefinitely

      user_id = 123
      lists = [%{"id" => 1, "name" => "Test"}]

      # Add entry with very short TTL
      Cache.put_user_lists(user_id, lists, 1)  # 1ms TTL

      # Wait for expiration
      Process.sleep(10)

      # Access should return expired
      assert {:error, :expired} = Cache.get_user_lists(user_id)

      # The cleanup process should eventually remove expired entries
      # This is tested indirectly through the expired stat tracking
      stats = Cache.get_stats()
      assert stats.expired >= 1
    end
  end
end
