defmodule Flixir.Auth.SessionCleanup do
  @moduledoc """
  Background job for cleaning up expired authentication sessions.

  This module provides functionality to:
  - Clean up expired sessions from the database
  - Schedule periodic cleanup tasks
  - Handle cleanup errors gracefully
  - Log cleanup statistics
  """

  use GenServer

  alias Flixir.Auth

  require Logger

  # 5 minutes
  @initial_delay_ms 5 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually trigger session cleanup.

  Returns the number of sessions that were cleaned up.

  ## Examples

      iex> cleanup_expired_sessions()
      {:ok, 5}  # 5 sessions were cleaned up

      iex> cleanup_expired_sessions()
      {:error, :database_error}
  """
  def cleanup_expired_sessions do
    GenServer.call(__MODULE__, :cleanup_now)
  end

  @doc """
  Get cleanup statistics.

  ## Examples

      iex> get_stats()
      %{
        last_cleanup_at: ~U[2024-01-01 12:00:00Z],
        total_cleanups: 10,
        total_sessions_cleaned: 45,
        last_cleanup_count: 3
      }
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    # Get cleanup interval from configuration or use default
    config_interval_seconds = Application.get_env(:flixir, :tmdb_auth)[:cleanup_interval] || 3600
    cleanup_interval = Keyword.get(opts, :cleanup_interval_ms, config_interval_seconds * 1000)
    initial_delay = Keyword.get(opts, :initial_delay_ms, @initial_delay_ms)

    Process.send_after(self(), :cleanup, initial_delay)

    state = %{
      cleanup_interval: cleanup_interval,
      last_cleanup_at: nil,
      total_cleanups: 0,
      total_sessions_cleaned: 0,
      last_cleanup_count: 0
    }

    Logger.info("Session cleanup service started with #{cleanup_interval}ms interval")

    {:ok, state}
  end

  @impl true
  def handle_call(:cleanup_now, _from, state) do
    case perform_cleanup() do
      {:ok, count} ->
        new_state = update_cleanup_stats(state, count)
        {:reply, {:ok, count}, new_state}

      {:error, reason} = error ->
        Logger.error("Manual session cleanup failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  def handle_call(:get_stats, _from, state) do
    {:reply,
     Map.take(state, [
       :last_cleanup_at,
       :total_cleanups,
       :total_sessions_cleaned,
       :last_cleanup_count
     ]), state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Perform cleanup
    new_state =
      case perform_cleanup() do
        {:ok, count} ->
          Logger.info("Cleaned up #{count} expired sessions")
          update_cleanup_stats(state, count)

        {:error, reason} ->
          Logger.error("Scheduled session cleanup failed: #{inspect(reason)}")
          state
      end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, state.cleanup_interval)

    {:noreply, new_state}
  end

  # Private functions

  defp perform_cleanup do
    try do
      {count, _} = Auth.cleanup_expired_sessions()
      {:ok, count}
    rescue
      error ->
        {:error, error}
    catch
      :exit, reason ->
        {:error, {:exit, reason}}
    end
  end

  defp update_cleanup_stats(state, count) do
    %{
      state
      | last_cleanup_at: DateTime.utc_now(),
        total_cleanups: state.total_cleanups + 1,
        total_sessions_cleaned: state.total_sessions_cleaned + count,
        last_cleanup_count: count
    }
  end
end
