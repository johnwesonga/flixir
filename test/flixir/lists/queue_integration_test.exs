defmodule Flixir.Lists.QueueIntegrationTest do
  use Flixir.DataCase, async: true

  alias Flixir.Lists.{Queue, QueuedOperation, QueueProcessor}
  alias Flixir.Repo

  import Mock

  describe "queue integration" do
    test "end-to-end queue processing workflow" do
      # Create a queued operation
      assert {:ok, operation} = Queue.enqueue_operation(
        "create_list",
        123,
        nil,
        %{"name" => "Integration Test List"}
      )

      assert operation.status == "pending"
      assert operation.retry_count == 0

      # Mock the dependencies for processing
      with_mocks([
        {Flixir.Auth, [], [get_user_session: fn(_) -> {:ok, "session_123"} end]},
        {Flixir.Lists.TMDBClient, [], [create_list: fn(_, _) -> {:ok, %{list_id: 456}} end]}
      ]) do
        # Process the operation
        assert {:ok, _result} = Queue.process_operation(operation)

        # Verify operation was completed
        updated_operation = Repo.get(QueuedOperation, operation.id)
        assert updated_operation.status == "completed"
      end
    end

    test "queue statistics and monitoring" do
      # Create operations with different statuses
      _pending_op = insert_queued_operation(%{status: "pending"})
      _completed_op = insert_queued_operation(%{status: "completed"})
      _failed_op = insert_queued_operation(%{status: "failed"})

      stats = Queue.get_queue_stats()

      assert stats.pending >= 1
      assert stats.completed >= 1
      assert stats.failed >= 1
      assert stats.total >= 3
    end

    test "user-specific queue operations" do
      user1_op = insert_queued_operation(%{tmdb_user_id: 123, status: "pending"})
      user2_op = insert_queued_operation(%{tmdb_user_id: 456, status: "pending"})
      _user1_completed = insert_queued_operation(%{tmdb_user_id: 123, status: "completed"})

      user1_pending = Queue.get_user_pending_operations(123)
      user2_pending = Queue.get_user_pending_operations(456)

      assert length(user1_pending) == 1
      assert hd(user1_pending).id == user1_op.id

      assert length(user2_pending) == 1
      assert hd(user2_pending).id == user2_op.id
    end

    test "retry failed operations" do
      failed_op = insert_queued_operation(%{
        status: "failed",
        retry_count: 2,
        operation_data: %{"name" => "Retry Test List"}
      })

      with_mocks([
        {Flixir.Auth, [], [get_user_session: fn(_) -> {:ok, "session_123"} end]},
        {Flixir.Lists.TMDBClient, [], [create_list: fn(_, _) -> {:ok, %{list_id: 789}} end]}
      ]) do
        assert {:ok, _result} = Queue.retry_operation(failed_op.id)

        updated_operation = Repo.get(QueuedOperation, failed_op.id)
        assert updated_operation.status == "completed"
      end
    end

    test "operation deduplication" do
      # Create first operation
      assert {:ok, first_op} = Queue.enqueue_operation(
        "add_movie",
        123,
        456,
        %{"movie_id" => 789}
      )

      # Try to create duplicate
      assert {:ok, duplicate_op} = Queue.enqueue_operation(
        "add_movie",
        123,
        456,
        %{"movie_id" => 789}
      )

      # Should return the same operation
      assert first_op.id == duplicate_op.id

      # Verify only one operation exists in database
      operations = from(op in QueuedOperation,
        where: op.tmdb_user_id == 123 and
               op.tmdb_list_id == 456 and
               op.operation_type == "add_movie"
      ) |> Repo.all()

      assert length(operations) == 1
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
