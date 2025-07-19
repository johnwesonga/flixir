defmodule Flixir.Reviews.Cache do
  @moduledoc """
  ETS-based caching system for movie and TV show reviews and ratings.

  Provides TTL-based cache expiration:
  - Reviews: 1 hour TTL
  - Ratings: 30 minutes TTL
  """

  use GenServer
  require Logger

  @table_name :reviews_cache
  @reviews_ttl :timer.hours(1)
  @ratings_ttl :timer.minutes(30)

  # Client API

  @doc """
  Starts the cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets cached data by key.
  Returns `{:ok, data}` if found and not expired, `:error` otherwise.
  """
  @spec get(String.t()) :: {:ok, any()} | :error
  def get(cache_key) do
    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, data, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          {:ok, data}
        else
          # Clean up expired entry
          :ets.delete(@table_name, cache_key)
          :error
        end

      [] ->
        :error
    end
  end

  @doc """
  Stores data in cache with TTL.
  """
  @spec put(String.t(), any(), pos_integer()) :: :ok
  def put(cache_key, data, ttl \\ @reviews_ttl) do
    expires_at = System.system_time(:millisecond) + ttl
    :ets.insert(@table_name, {cache_key, data, expires_at})
    :ok
  end

  @doc """
  Generates cache key for reviews.
  """
  @spec reviews_cache_key(String.t(), String.t(), map()) :: String.t()
  def reviews_cache_key(media_type, media_id, filters \\ %{}) do
    filter_string =
      filters
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}:#{v}" end)
      |> Enum.join(",")

    "reviews:#{media_type}:#{media_id}:#{filter_string}"
  end

  @doc """
  Generates cache key for rating statistics.
  """
  @spec ratings_cache_key(String.t(), String.t()) :: String.t()
  def ratings_cache_key(media_type, media_id) do
    "ratings:#{media_type}:#{media_id}"
  end

  @doc """
  Stores reviews in cache with 1-hour TTL.
  """
  @spec put_reviews(String.t(), String.t(), any(), map()) :: :ok
  def put_reviews(media_type, media_id, reviews, filters \\ %{}) do
    cache_key = reviews_cache_key(media_type, media_id, filters)
    put(cache_key, reviews, @reviews_ttl)
  end

  @doc """
  Gets cached reviews.
  """
  @spec get_reviews(String.t(), String.t(), map()) :: {:ok, any()} | :error
  def get_reviews(media_type, media_id, filters \\ %{}) do
    cache_key = reviews_cache_key(media_type, media_id, filters)
    get(cache_key)
  end

  @doc """
  Stores rating statistics in cache with 30-minute TTL.
  """
  @spec put_ratings(String.t(), String.t(), any()) :: :ok
  def put_ratings(media_type, media_id, ratings) do
    cache_key = ratings_cache_key(media_type, media_id)
    put(cache_key, ratings, @ratings_ttl)
  end

  @doc """
  Gets cached rating statistics.
  """
  @spec get_ratings(String.t(), String.t()) :: {:ok, any()} | :error
  def get_ratings(media_type, media_id) do
    cache_key = ratings_cache_key(media_type, media_id)
    get(cache_key)
  end

  @doc """
  Clears all cached data.
  """
  @spec clear_all() :: :ok
  def clear_all do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Removes expired entries from cache.
  """
  @spec cleanup_expired() :: :ok
  def cleanup_expired do
    current_time = System.system_time(:millisecond)

    :ets.foldl(
      fn {key, _data, expires_at}, acc ->
        if current_time >= expires_at do
          :ets.delete(@table_name, key)
        end

        acc
      end,
      :ok,
      @table_name
    )

    :ok
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for cache storage
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    # Schedule periodic cleanup of expired entries
    schedule_cleanup()

    Logger.info("Reviews cache started with table: #{@table_name}")
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp schedule_cleanup do
    # Clean up expired entries every 5 minutes
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end
end
