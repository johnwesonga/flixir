defmodule Flixir.Lists.QueueTest do
  use Flixir.DataCase, async: true

  alias Flixir.Lists.{Queue, QueuedOperation}
  alias Flixir.Repo

  import Mock

  describe "enqueue_operation/4" do
    test "creates a new queued operation" do
      operation_data = %{"name" => "My Test List", "description" => "Test description"}

      assert {:ok, operation} = Queue.enqueue_operation("create_list", 123, nil, operation_data)

      assert operation.operation_type == "create_list"
      assert operation.tmdb_user_id == 123
      assert operation.tmdb_list_id == nil
      assert operation.operation_data == operation_data
      assert operation.status == "pending"
      assert operation.retry_count == 0
    end

    test "prevents duplicate create_list operations with same name" do
      operation_data = %{"name" => "Duplicate List"}

      # Create first operation
      assert {:ok, first_op} = Queue.enqueue_operation("create_list", 123, nil, operation_data)

      # Try to create duplicate
      assert {:ok, duplicate_op} = Queue.enqueue_operation("create_list", 123, nil, operation_data)

      # Should return the existing operation
      assert first_op.id == duplicate_op.id
    end

    test "prevents duplicate add_movie operations" do
      operation_data = %{"movie_id" => 456}

      # Create first operation
      assert {:ok, first_op} = Queue.enqueue_operation("add_movie", 123, 789, operation_data)

      # Try to create duplicate
      assert {:ok, duplicate_op} = Queue.enqueue_operation("add_movie", 123, 789, operation_data)

      # Should return the existing operation
      assert first_op.id == duplicate_op.id
    end

    test "allows different operations for same user" do
      # Create different operations for same user
      assert {:ok, op1} = Queue.enqueue_operation("create_list", 123, nil, %{"name" => "List 1"})
      assert {:ok, op2} = Queue.enqueue_operation("create_list", 123, nil, %{"name" => "List 2"})

      # Should be different operations
      assert op1.id != op2.id
    end
  end

  describe "process_operation/1" do
    test "marks operation as processing then completed on success" do
      operation = insert_queued_operation(%{
        operation_type: "create_list",
        operation_data: %{"name" => "Test List"}
      })

      with_mocks([
        {Flixir.Auth, [], [get_user_session: fn(_) -> {:ok, "session_123"} end]},
        {Flixir.Lists.TMDBClient, [], [create_list: fn(_, _) -> {:ok, %{list_id: 456}} end]}
      ]) do
        assert {:ok, _result} = Queue.process_operation(operation)

        updated_operation = Repo.get(QueuedOperation, operation.id)
        assert updated_operation.status == "completed"
      end
    end

    test "handles auth failure" do
      operation = insert_queued_operation(%{
        operation_type: "create_list",
        operation_data: %{"name" => "Test List"}
      })

      with_mock Flixir.Auth, [get_user_session: fn(_) -> {:error, :no_valid_session} end] do
        assert {:error, {:scheduled_retry, _delay}} = Queue.process_operation(operation)

        updated_operation = Repo.get(QueuedOperation, operation.id)
        assert updated_operation.status == "pending"
        assert updated_operation.retry_count == 1
      end
    end

    test "handles TMDB API failure with retry" do
      operation = insert_queued_operation(%{
        operation_type: "create_list",
        operation_data: %{"name" => "Test List"}
      })

      with_mocks([
        {Flixir.Auth, [], [get_user_session: fn(_) -> {:ok, "session_123"} end]},
        {Flixir.Lists.TMDBClient, [], [create_list: fn(_, _) -> {:error, :api_error} end]}
      ]) do
        assert {:error, {:scheduled_retry, _delay}} = Queue.process_operation(operation)

        updated_operation = Repo.get(QueuedOperation, operation.id)
        assert updated_operation.status == "pending"
        assert updated_operation.retry_count == 1
        assert updated_operation.scheduled_for != nil
      end
    end

    test "marks operation as failed after max retries" do
      operation = insert_queued_operation(%{
        operation_type: "create_list",
        operation_data: %{"name" => "Test List"},
        retry_count: 4  # One less than max
      })

      with_mocks([
        {Flixir.Auth, [], [get_user_session: fn(_) -> {:ok, "session_123"} end]},
        {Flixir.Lists.TMDBClient, [], [create_list: fn(_, _) -> {:error, :api_error} end]}
      ]) do
        assert {:error, :max_retries_exceeded} = Queue.process_operation(operation)

        updated_operation = Repo.get(QueuedOperation, operation.id)
        assert updated_operation.status == "failed"
        assert updated_operation.retry_count == 5
      end
    end
  end

  describe "process_pending_operations/0" do
    test "processes all pending operations" do
      # Create multiple pending operations
      op1 = insert_queued_operation(%{operation_type: "create_list", operation_data: %{"name" => "List 1"}})
      op2 = insert_queued_operation(%{operation_type: "create_list", operation_data: %{"name" => "List 2"}})

      # Create a scheduled operation (should not be processed)
      _op3 = insert_queued_operation(%{
        operation_type: "create_list",
        operation_data: %{"name" => "List 3"},
        scheduled_for: DateTime.utc_now() |> DateTime.add(3600, :second)
      })

      with_mocks([
        {Flixir.Auth, [], [get_user_session: fn(_) -> {:ok, "session_123"} end]},
        {Flixir.Lists.TMDBClient, [], [create_list: fn(_, _) -> {:ok, %{list_id: 456}} end]}
      ]) do
        Queue.process_pending_operations()

        # Check that pending operations were processed
        updated_op1 = Repo.get(QueuedOperation, op1.id)
        updated_op2 = Repo.get(QueuedOperation, op2.id)

        assert updated_op1.status == "completed"
        assert updated_op2.status == "completed"
      end
    end
  end

  describe "retry_operation/1" do
    test "retries a failed operation" do
      operation = insert_queued_operation(%{
        operation_type: "create_list",
        operation_data: %{"name" => "Test List"},
        status: "failed",
        retry_count: 2
      })

      with_mocks([
        {Flixir.Auth, [], [get_user_session: fn(_) -> {:ok, "session_123"} end]},
        {Flixir.Lists.TMDBClient, [], [create_list: fn(_, _) -> {:ok, %{list_id: 456}} end]}
      ]) do
        assert {:ok, _result} = Queue.retry_operation(operation.id)

        updated_operation = Repo.get(QueuedOperation, operation.id)
        assert updated_operation.status == "completed"
      end
    end

    test "returns error for non-existent operation" do
      assert {:error, :not_found} = Queue.retry_operation(Ecto.UUID.generate())
    end

    test "returns error for operation with invalid status" do
      operation = insert_queued_operation(%{status: "completed"})

      assert {:error, {:invalid_status, "completed"}} = Queue.retry_operation(operation.id)
    end
  end

  describe "get_queue_stats/0" do
    test "returns correct statistics" do
      # Create operations with different statuses
      insert_queued_operation(%{status: "pending"})
      insert_queued_operation(%{status: "pending"})
      insert_queued_operation(%{status: "completed"})
      insert_queued_operation(%{status: "failed"})

      stats = Queue.get_queue_stats()

      assert stats.pending == 2
      assert stats.completed == 1
      assert stats.failed == 1
      assert stats.processing == 0
      assert stats.cancelled == 0
      assert stats.total == 4
    end
  end

  describe "get_user_pending_operations/1" do
    test "returns pending operations for specific user" do
      user1_op1 = insert_queued_operation(%{tmdb_user_id: 123, status: "pending"})
      user1_op2 = insert_queued_operation(%{tmdb_user_id: 123, status: "processing"})
      _user1_op3 = insert_queued_operation(%{tmdb_user_id: 123, status: "completed"})
      _user2_op = insert_queued_operation(%{tmdb_user_id: 456, status: "pending"})

      operations = Queue.get_user_pending_operations(123)

      assert length(operations) == 2
      operation_ids = Enum.map(operations, & &1.id)
      assert user1_op1.id in operation_ids
      assert user1_op2.id in operation_ids
    end
  end

  describe "get_failed_operations/1" do
    test "returns failed operations that can be retried" do
      # Failed operation that can be retried
      retryable_op = insert_queued_operation(%{status: "failed", retry_count: 2})

      # Failed operation that exceeded max retries
      _max_retries_op = insert_queued_operation(%{status: "failed", retry_count: 5})

      # Non-failed operation
      _pending_op = insert_queued_operation(%{status: "pending"})

      operations = Queue.get_failed_operations()

      assert length(operations) == 1
      assert hd(operations).id == retryable_op.id
    end
  end

  describe "cancel_operation/1" do
    test "cancels a pending operation" do
      operation = insert_queued_operation(%{status: "pending"})

      assert {:ok, updated_operation} = Queue.cancel_operation(operation.id)
      assert updated_operation.status == "cancelled"
    end

    test "cancels a processing operation" do
      operation = insert_queued_operation(%{status: "processing"})

      assert {:ok, updated_operation} = Queue.cancel_operation(operation.id)
      assert updated_operation.status == "cancelled"
    end

    test "returns error for completed operation" do
      operation = insert_queued_operation(%{status: "completed"})

      assert {:error, {:invalid_status, "completed"}} = Queue.cancel_operation(operation.id)
    end
  end

  describe "cleanup_old_operations/1" do
    test "removes old completed and cancelled operations" do
      # Old completed operation (should be deleted)
      old_completed = insert_queued_operation(%{status: "completed"})
      old_completed = update_operation_timestamp(old_completed, DateTime.utc_now() |> DateTime.add(-31, :day))

      # Old cancelled operation (should be deleted)
      old_cancelled = insert_queued_operation(%{status: "cancelled"})
      old_cancelled = update_operation_timestamp(old_cancelled, DateTime.utc_now() |> DateTime.add(-31, :day))

      # Recent completed operation (should not be deleted)
      recent_completed = insert_queued_operation(%{status: "completed"})
      recent_completed = update_operation_timestamp(recent_completed, DateTime.utc_now() |> DateTime.add(-1, :day))

      # Old failed operation (should not be deleted)
      old_failed = insert_queued_operation(%{status: "failed"})
      old_failed = update_operation_timestamp(old_failed, DateTime.utc_now() |> DateTime.add(-31, :day))

      {deleted_count, _} = Queue.cleanup_old_operations(30)

      assert deleted_count == 2

      # Verify correct operations were deleted
      assert Repo.get(QueuedOperation, old_completed.id) == nil
      assert Repo.get(QueuedOperation, old_cancelled.id) == nil
      assert Repo.get(QueuedOperation, recent_completed.id) != nil
      assert Repo.get(QueuedOperation, old_failed.id) != nil
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

  defp update_operation_timestamp(operation, timestamp) do
    # Directly update the timestamp in the database
    from(op in QueuedOperation, where: op.id == ^operation.id)
    |> Repo.update_all(set: [updated_at: timestamp])

    # Return the operation with updated timestamp
    %{operation | updated_at: timestamp}
  end
end
