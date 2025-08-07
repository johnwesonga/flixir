defmodule Flixir.Lists.Cache do
  @moduledoc """
  Cache layer for TMDB list data using ETS for high-performance local caching.

  Provides caching for:
  - User lists metadata
  - List items and movies
  - Cache statistics and monitoring
  - Automatic expiration and invalidation
  """

  use GenServer
  require Logger

  @cache_table :tmdb_lists_cache
  @stats_table :tmdb_lists_cache_stats
  @default_ttl :timer.hours(1)
  @cleanup_interval :timer.minutes(5)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store user lists in cache with TTL.
  """
  @spec put_user_lists(integer(), [map()], integer()) :: :ok
  def put_user_lists(tmdb_user_id, lists, ttl \\ @default_ttl) do
    expires_at = System.system_time(:millisecond) + ttl
    key = {:user_lists, tmdb_user_id}

    :ets.insert(@cache_table, {key, lists, expires_at})
    increment_stat(:writes)

    Logger.debug("Cached #{length(lists)} lists for user #{tmdb_user_id}")
    :ok
  end

  @doc """
  Retrieve user lists from cache.
  """
  @spec get_user_lists(integer()) :: {:ok, [map()]} | {:error, :not_found | :expired}
  def get_user_lists(tmdb_user_id) do
    key = {:user_lists, tmdb_user_id}

    case :ets.lookup(@cache_table, key) do
      [{^key, lists, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          increment_stat(:hits)
          Logger.debug("Cache hit for user #{tmdb_user_id} lists")
          {:ok, lists}
        else
          :ets.delete(@cache_table, key)
          increment_stat(:misses)
          increment_stat(:expired)
          Logger.debug("Cache expired for user #{tmdb_user_id} lists")
          {:error, :expired}
        end

      [] ->
        increment_stat(:misses)
        Logger.debug("Cache miss for user #{tmdb_user_id} lists")
        {:error, :not_found}
    end
  end

  @doc """
  Store individual list data in cache.
  """
  @spec put_list(map(), integer()) :: :ok
  def put_list(list_data, ttl \\ @default_ttl) do
    expires_at = System.system_time(:millisecond) + ttl
    key = {:list, list_data["id"]}

    :ets.insert(@cache_table, {key, list_data, expires_at})
    increment_stat(:writes)

    Logger.debug("Cached list #{list_data["id"]}: #{list_data["name"]}")
    :ok
  end

  @doc """
  Retrieve individual list from cache.
  """
  @spec get_list(integer()) :: {:ok, map()} | {:error, :not_found | :expired}
  def get_list(list_id) do
    key = {:list, list_id}

    case :ets.lookup(@cache_table, key) do
      [{^key, list_data, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          increment_stat(:hits)
          Logger.debug("Cache hit for list #{list_id}")
          {:ok, list_data}
        else
          :ets.delete(@cache_table, key)
          increment_stat(:misses)
          increment_stat(:expired)
          Logger.debug("Cache expired for list #{list_id}")
          {:error, :expired}
        end

      [] ->
        increment_stat(:misses)
        Logger.debug("Cache miss for list #{list_id}")
        {:error, :not_found}
    end
  end

  @doc """
  Store list items (movies) in cache.
  """
  @spec put_list_items(integer(), [map()], integer()) :: :ok
  def put_list_items(list_id, items, ttl \\ @default_ttl) do
    expires_at = System.system_time(:millisecond) + ttl
    key = {:list_items, list_id}

    :ets.insert(@cache_table, {key, items, expires_at})
    increment_stat(:writes)

    Logger.debug("Cached #{length(items)} items for list #{list_id}")
    :ok
  end

  @doc """
  Retrieve list items from cache.
  """
  @spec get_list_items(integer()) :: {:ok, [map()]} | {:error, :not_found | :expired}
  def get_list_items(list_id) do
    key = {:list_items, list_id}

    case :ets.lookup(@cache_table, key) do
      [{^key, items, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          increment_stat(:hits)
          Logger.debug("Cache hit for list #{list_id} items")
          {:ok, items}
        else
          :ets.delete(@cache_table, key)
          increment_stat(:misses)
          increment_stat(:expired)
          Logger.debug("Cache expired for list #{list_id} items")
          {:error, :expired}
        end

      [] ->
        increment_stat(:misses)
        Logger.debug("Cache miss for list #{list_id} items")
        {:error, :not_found}
    end
  end

  @doc """
  Invalidate all cache entries for a specific user.
  """
  @spec invalidate_user_cache(integer()) :: :ok
  def invalidate_user_cache(tmdb_user_id) do
    # Remove user lists cache
    user_lists_key = {:user_lists, tmdb_user_id}
    :ets.delete(@cache_table, user_lists_key)

    # Remove all individual lists owned by this user
    # Note: This requires tracking user ownership, simplified for now
    increment_stat(:invalidations)

    Logger.info("Invalidated cache for user #{tmdb_user_id}")
    :ok
  end

  @doc """
  Invalidate cache for a specific list.
  """
  @spec invalidate_list_cache(integer()) :: :ok
  def invalidate_list_cache(list_id) do
    list_key = {:list, list_id}
    items_key = {:list_items, list_id}

    :ets.delete(@cache_table, list_key)
    :ets.delete(@cache_table, items_key)
    increment_stat(:invalidations)

    Logger.info("Invalidated cache for list #{list_id}")
    :ok
  end

  @doc """
  Warm cache for frequently accessed lists.
  """
  @spec warm_cache(integer(), [integer()]) :: :ok
  def warm_cache(tmdb_user_id, list_ids) do
    GenServer.cast(__MODULE__, {:warm_cache, tmdb_user_id, list_ids})
  end

  @doc """
  Get cache statistics for monitoring.
  """
  @spec get_stats() :: map()
  def get_stats do
    hits = get_stat_value(:hits)
    misses = get_stat_value(:misses)
    writes = get_stat_value(:writes)
    expired = get_stat_value(:expired)
    invalidations = get_stat_value(:invalidations)

    %{
      hits: hits,
      misses: misses,
      writes: writes,
      expired: expired,
      invalidations: invalidations
    }
  end

  @doc """
  Reset cache statistics.
  """
  @spec reset_stats() :: :ok
  def reset_stats do
    :ets.insert(@stats_table, {:hits, 0})
    :ets.insert(@stats_table, {:misses, 0})
    :ets.insert(@stats_table, {:writes, 0})
    :ets.insert(@stats_table, {:expired, 0})
    :ets.insert(@stats_table, {:invalidations, 0})
    :ok
  end

  @doc """
  Clear all cache entries.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    :ets.delete_all_objects(@cache_table)
    increment_stat(:invalidations)
    Logger.info("Cleared all cache entries")
    :ok
  end

  @doc """
  Get cache size and memory usage.
  """
  @spec get_cache_info() :: map()
  def get_cache_info do
    info = :ets.info(@cache_table)

    %{
      size: Keyword.get(info, :size, 0),
      memory: Keyword.get(info, :memory, 0),
      memory_bytes: Keyword.get(info, :memory, 0) * :erlang.system_info(:wordsize)
    }
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@cache_table, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@stats_table, [:named_table, :public, :set, {:read_concurrency, true}])

    # Initialize stats
    reset_stats()

    # Schedule periodic cleanup
    schedule_cleanup()

    Logger.info("TMDB Lists Cache started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:warm_cache, tmdb_user_id, list_ids}, state) do
    Task.start(fn -> perform_cache_warming(tmdb_user_id, list_ids) end)
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp increment_stat(stat_name) do
    :ets.update_counter(@stats_table, stat_name, 1, {stat_name, 0})
  end

  defp get_stat_value(stat_name) do
    case :ets.lookup(@stats_table, stat_name) do
      [{^stat_name, value}] -> value
      [] -> 0
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval)
  end

  defp cleanup_expired_entries do
    current_time = System.system_time(:millisecond)
    expired_count =
      @cache_table
      |> :ets.tab2list()
      |> Enum.count(fn {key, _value, expires_at} ->
        if current_time >= expires_at do
          :ets.delete(@cache_table, key)
          true
        else
          false
        end
      end)

    if expired_count > 0 do
      Logger.debug("Cleaned up #{expired_count} expired cache entries")
    end
  end

  defp perform_cache_warming(tmdb_user_id, list_ids) do
    Logger.info("Starting cache warming for user #{tmdb_user_id}, lists: #{inspect(list_ids)}")

    # This would typically fetch from TMDB API and cache the results
    # For now, we'll just log the warming attempt
    # In a real implementation, this would call the TMDB client

    Logger.info("Cache warming completed for user #{tmdb_user_id}")
  end
end
