defmodule Flixir.Media.Cache do
  @moduledoc """
  GenServer-based cache manager for search results with ETS storage and TTL functionality.

  This module provides caching capabilities for TMDB search results to improve performance
  and reduce API calls. It uses ETS for fast lookups and implements TTL (time-to-live)
  for automatic cache expiration.
  """

  use GenServer
  require Logger

  # 5 minutes
  @default_ttl_seconds 300
  @default_max_entries 1000
  # 1 minute
  @cleanup_interval 60_000

  # Client API

  @doc """
  Starts the cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieves a value from the cache by key.
  Returns {:ok, value} if found and not expired, :error otherwise.
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Stores a value in the cache with the specified key and optional TTL.
  TTL defaults to the configured default TTL.
  """
  def put(key, value, ttl_seconds \\ nil) do
    GenServer.cast(__MODULE__, {:put, key, value, ttl_seconds})
  end

  @doc """
  Removes a specific key from the cache.
  """
  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  @doc """
  Clears all entries from the cache.
  """
  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  @doc """
  Returns cache statistics including size, hits, misses, and memory usage.
  """
  def stats() do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Generates a cache key for search queries.
  """
  def search_key(query, opts \\ []) do
    media_type = Keyword.get(opts, :media_type, :all)
    sort_by = Keyword.get(opts, :sort_by, :relevance)
    page = Keyword.get(opts, :page, 1)

    "search:#{String.downcase(String.trim(query))}:#{media_type}:#{sort_by}:#{page}"
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    ttl_seconds = Keyword.get(opts, :ttl_seconds, @default_ttl_seconds)
    max_entries = Keyword.get(opts, :max_entries, @default_max_entries)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @cleanup_interval)

    # Create ETS table for cache storage
    table = :ets.new(:search_cache, [:set, :protected, :named_table])

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, cleanup_interval)

    state = %{
      table: table,
      ttl_seconds: ttl_seconds,
      max_entries: max_entries,
      cleanup_interval: cleanup_interval,
      stats: %{hits: 0, misses: 0, evictions: 0}
    }

    Logger.info("Search cache started with TTL: #{ttl_seconds}s, max entries: #{max_entries}")

    {:ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case :ets.lookup(state.table, key) do
      [{^key, value, expires_at}] ->
        if System.system_time(:second) < expires_at do
          new_stats = Map.update!(state.stats, :hits, &(&1 + 1))
          {:reply, {:ok, value}, %{state | stats: new_stats}}
        else
          # Entry expired, remove it
          :ets.delete(state.table, key)
          new_stats = Map.update!(state.stats, :misses, &(&1 + 1))
          {:reply, :error, %{state | stats: new_stats}}
        end

      [] ->
        new_stats = Map.update!(state.stats, :misses, &(&1 + 1))
        {:reply, :error, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    cache_size = :ets.info(state.table, :size)
    memory_words = :ets.info(state.table, :memory)
    memory_bytes = memory_words * :erlang.system_info(:wordsize)

    stats =
      Map.merge(state.stats, %{
        size: cache_size,
        max_entries: state.max_entries,
        memory_bytes: memory_bytes,
        ttl_seconds: state.ttl_seconds
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:put, key, value, ttl_seconds}, state) do
    ttl = ttl_seconds || state.ttl_seconds
    expires_at = System.system_time(:second) + ttl

    # Check if we need to evict entries to stay under max_entries limit
    current_size = :ets.info(state.table, :size)

    new_state =
      if current_size >= state.max_entries do
        evict_oldest_entries(state, 1)
      else
        state
      end

    :ets.insert(new_state.table, {key, value, expires_at})

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:delete, key}, state) do
    :ets.delete(state.table, key)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:clear, state) do
    :ets.delete_all_objects(state.table)
    Logger.info("Search cache cleared")
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    {expired_count, new_state} = cleanup_expired_entries(state)

    if expired_count > 0 do
      Logger.debug("Cleaned up #{expired_count} expired cache entries")
    end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, state.cleanup_interval)

    {:noreply, new_state}
  end

  # Private Functions

  defp cleanup_expired_entries(state) do
    current_time = System.system_time(:second)

    # Find all expired entries
    expired_keys =
      :ets.foldl(
        fn {key, _value, expires_at}, acc ->
          if current_time >= expires_at do
            [key | acc]
          else
            acc
          end
        end,
        [],
        state.table
      )

    # Delete expired entries
    Enum.each(expired_keys, fn key ->
      :ets.delete(state.table, key)
    end)

    expired_count = length(expired_keys)
    new_stats = Map.update!(state.stats, :evictions, &(&1 + expired_count))

    {expired_count, %{state | stats: new_stats}}
  end

  defp evict_oldest_entries(state, count) do
    # Get all entries sorted by expiration time (oldest first)
    all_entries = :ets.tab2list(state.table)

    oldest_entries =
      all_entries
      |> Enum.sort_by(fn {_key, _value, expires_at} -> expires_at end)
      |> Enum.take(count)

    # Delete oldest entries
    Enum.each(oldest_entries, fn {key, _value, _expires_at} ->
      :ets.delete(state.table, key)
    end)

    evicted_count = length(oldest_entries)
    new_stats = Map.update!(state.stats, :evictions, &(&1 + evicted_count))

    Logger.debug("Evicted #{evicted_count} oldest cache entries to make room")

    %{state | stats: new_stats}
  end
end
