defmodule Flixir.Lists.QueueProcessor do
  @moduledoc """
  Background job processor for handling queued list operations.

  This GenServer runs periodically to process pending operations in the queue,
  handling retries and monitoring queue health.
  """

  use GenServer
  require Logger

  alias Flixir.Lists.Queue

  @process_interval :timer.minutes(1)  # Process queue every minute
  @cleanup_interval :timer.hours(24)   # Cleanup old operations daily

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually triggers queue processing.
  """
  def process_now do
    GenServer.cast(__MODULE__, :process_queue)
  end

  @doc """
  Gets current processor status and statistics.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Enables or disables the queue processor.
  """
  def set_enabled(enabled) when is_boolean(enabled) do
    GenServer.cast(__MODULE__, {:set_enabled, enabled})
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    enabled = Keyword.get(opts, :enabled, true)

    if enabled do
      schedule_processing()
      schedule_cleanup()
    end

    state = %{
      enabled: enabled,
      last_processed_at: nil,
      last_cleanup_at: nil,
      processing_count: 0,
      total_processed: 0,
      total_failed: 0
    }

    Logger.info("Queue processor started (enabled: #{enabled})")

    {:ok, state}
  end

  @impl true
  def handle_cast(:process_queue, state) do
    if state.enabled do
      new_state = process_queue(state)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:set_enabled, enabled}, state) do
    Logger.info("Queue processor enabled: #{enabled}")

    new_state = %{state | enabled: enabled}

    if enabled and not state.enabled do
      # Re-enable: schedule processing
      schedule_processing()
      schedule_cleanup()
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    queue_stats = Queue.get_queue_stats()

    status = %{
      enabled: state.enabled,
      last_processed_at: state.last_processed_at,
      last_cleanup_at: state.last_cleanup_at,
      processing_count: state.processing_count,
      total_processed: state.total_processed,
      total_failed: state.total_failed,
      queue_stats: queue_stats
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:process_queue, state) do
    new_state = if state.enabled do
      process_queue(state)
    else
      state
    end

    schedule_processing()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup_old_operations, state) do
    new_state = if state.enabled do
      cleanup_operations(state)
    else
      state
    end

    schedule_cleanup()
    {:noreply, new_state}
  end

  # Private functions

  defp process_queue(state) do
    Logger.debug("Processing queue...")

    start_time = System.monotonic_time(:millisecond)

    try do
      Queue.process_pending_operations()

      processing_time = System.monotonic_time(:millisecond) - start_time
      Logger.debug("Queue processing completed in #{processing_time}ms")

      %{state |
        last_processed_at: DateTime.utc_now(),
        total_processed: state.total_processed + 1
      }
    rescue
      error ->
        Logger.error("Queue processing failed: #{inspect(error)}")

        %{state |
          last_processed_at: DateTime.utc_now(),
          total_failed: state.total_failed + 1
        }
    end
  end

  defp cleanup_operations(state) do
    Logger.debug("Cleaning up old operations...")

    try do
      {deleted_count, _} = Queue.cleanup_old_operations()
      Logger.info("Cleaned up #{deleted_count} old operations")

      %{state | last_cleanup_at: DateTime.utc_now()}
    rescue
      error ->
        Logger.error("Operation cleanup failed: #{inspect(error)}")
        state
    end
  end

  defp schedule_processing do
    Process.send_after(self(), :process_queue, @process_interval)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_operations, @cleanup_interval)
  end
end
