defmodule Flixir.Lists.QueueProcessorTest do
  use Flixir.DataCase, async: false

  alias Flixir.Lists.{QueueProcessor, Queue, QueuedOperation}
  alias Flixir.Repo

  import Mock

  # Test module that doesn't conflict with the main QueueProcessor
  defmodule TestQueueProcessor do
    use GenServer

    def start_link(opts \\ []) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(Flixir.Lists.QueueProcessor, opts, name: name)
    end
  end

  describe "start_link/1" do
    test "starts with default enabled state" do
      {:ok, pid} = TestQueueProcessor.start_link(name: :test_processor_1)

      status = GenServer.call(pid, :get_status)
      assert status.enabled == true

      GenServer.stop(pid)
    end

    test "starts with disabled state when specified" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: false, name: :test_processor_2)

      status = GenServer.call(pid, :get_status)
      assert status.enabled == false

      GenServer.stop(pid)
    end
  end

  describe "set_enabled/1" do
    test "enables and disables processor" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: false, name: :test_processor_3)

      # Initially disabled
      status = GenServer.call(pid, :get_status)
      assert status.enabled == false

      # Enable
      GenServer.cast(pid, {:set_enabled, true})
      :timer.sleep(10)  # Allow cast to process

      status = GenServer.call(pid, :get_status)
      assert status.enabled == true

      # Disable
      GenServer.cast(pid, {:set_enabled, false})
      :timer.sleep(10)  # Allow cast to process

      status = GenServer.call(pid, :get_status)
      assert status.enabled == false

      GenServer.stop(pid)
    end
  end

  describe "process_now/0" do
    test "manually triggers queue processing" do
      # Create a pending operation
      operation = insert_queued_operation(%{
        operation_type: "create_list",
        operation_data: %{"name" => "Test List"}
      })

      {:ok, pid} = TestQueueProcessor.start_link(enabled: false, name: :test_processor_4)

      with_mocks([
        {Queue, [], [process_pending_operations: fn -> :ok end]}
      ]) do
        GenServer.cast(pid, :process_queue)
        :timer.sleep(50)  # Allow processing to complete

        # Verify process_pending_operations was called
        assert called(Queue.process_pending_operations())
      end

      GenServer.stop(pid)
    end
  end

  describe "get_status/0" do
    test "returns processor status and statistics" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: true, name: :test_processor_5)

      with_mock Queue, [get_queue_stats: fn -> %{pending: 2, completed: 5, failed: 1} end] do
        status = GenServer.call(pid, :get_status)

        assert status.enabled == true
        assert is_map(status.queue_stats)
        assert status.queue_stats.pending == 2
        assert status.queue_stats.completed == 5
        assert status.queue_stats.failed == 1
        assert status.total_processed >= 0
        assert status.total_failed >= 0
      end

      GenServer.stop(pid)
    end
  end

  describe "queue processing" do
    test "processes queue when enabled" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: true, name: :test_processor_6)

      with_mock Queue, [process_pending_operations: fn -> :ok end] do
        GenServer.cast(pid, :process_queue)
        :timer.sleep(50)  # Allow processing to complete

        status = GenServer.call(pid, :get_status)
        assert status.total_processed >= 1

        # Verify process_pending_operations was called
        assert called(Queue.process_pending_operations())
      end

      GenServer.stop(pid)
    end

    test "skips processing when disabled" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: false, name: :test_processor_7)

      with_mock Queue, [process_pending_operations: fn -> :ok end] do
        GenServer.cast(pid, :process_queue)
        :timer.sleep(50)  # Allow processing to complete

        # Verify process_pending_operations was NOT called
        refute called(Queue.process_pending_operations())
      end

      GenServer.stop(pid)
    end

    test "handles processing errors gracefully" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: true, name: :test_processor_8)

      with_mock Queue, [process_pending_operations: fn -> raise "Processing error" end] do
        GenServer.cast(pid, :process_queue)
        :timer.sleep(50)  # Allow processing to complete

        status = GenServer.call(pid, :get_status)
        assert status.total_failed >= 1

        # Process should still be running
        assert Process.alive?(pid)
      end

      GenServer.stop(pid)
    end
  end

  describe "cleanup operations" do
    test "performs cleanup when enabled" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: true, name: :test_processor_9)

      with_mock Queue, [cleanup_old_operations: fn -> {3, nil} end] do
        send(pid, :cleanup_old_operations)
        :timer.sleep(50)  # Allow cleanup to complete

        # Verify cleanup_old_operations was called
        assert called(Queue.cleanup_old_operations())
      end

      GenServer.stop(pid)
    end

    test "skips cleanup when disabled" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: false, name: :test_processor_10)

      with_mock Queue, [cleanup_old_operations: fn -> {3, nil} end] do
        send(pid, :cleanup_old_operations)
        :timer.sleep(50)  # Allow cleanup to complete

        # Verify cleanup_old_operations was NOT called
        refute called(Queue.cleanup_old_operations())
      end

      GenServer.stop(pid)
    end

    test "handles cleanup errors gracefully" do
      {:ok, pid} = TestQueueProcessor.start_link(enabled: true, name: :test_processor_11)

      with_mock Queue, [cleanup_old_operations: fn -> raise "Cleanup error" end] do
        send(pid, :cleanup_old_operations)
        :timer.sleep(50)  # Allow cleanup to complete

        # Process should still be running
        assert Process.alive?(pid)
      end

      GenServer.stop(pid)
    end
  end

  # Helper functions

  defp insert_queued_operation(attrs \\ %{}) do
    default_attrs = %{
      operation_type: "create_list",
      tmdb_user_id: 123,
      tmdb_list_id: nil,
      operation_data: %{"name" => "Test List"},
      status: "pending",
      retry_count: 0,
      scheduled_for: DateTime.utc_now()
    }

    attrs = Map.merge(default_attrs, attrs)

    %QueuedOperation{}
    |> QueuedOperation.changeset(attrs)
    |> Repo.insert!()
  end
end
