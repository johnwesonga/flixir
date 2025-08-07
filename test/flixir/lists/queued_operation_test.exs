defmodule Flixir.Lists.QueuedOperationTest do
  use Flixir.DataCase, async: true

  alias Flixir.Lists.QueuedOperation

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        operation_type: "create_list",
        tmdb_user_id: 123,
        operation_data: %{"name" => "My List"}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :operation_type) == "create_list"
      assert get_change(changeset, :tmdb_user_id) == 123
      assert get_change(changeset, :operation_data) == %{"name" => "My List"}
    end

    test "invalid changeset with missing required fields" do
      changeset = QueuedOperation.changeset(%QueuedOperation{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).operation_type
      assert "can't be blank" in errors_on(changeset).tmdb_user_id
      assert "can't be blank" in errors_on(changeset).operation_data
    end

    test "invalid changeset with invalid operation_type" do
      attrs = %{
        operation_type: "invalid_operation",
        tmdb_user_id: 123,
        operation_data: %{"name" => "My List"}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).operation_type
    end

    test "invalid changeset with invalid status" do
      attrs = %{
        operation_type: "create_list",
        tmdb_user_id: 123,
        operation_data: %{"name" => "My List"},
        status: "invalid_status"
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "invalid changeset with negative retry_count" do
      attrs = %{
        operation_type: "create_list",
        tmdb_user_id: 123,
        operation_data: %{"name" => "My List"},
        retry_count: -1
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).retry_count
    end

    test "validates operation_data for create_list" do
      # Valid create_list data
      valid_attrs = %{
        operation_type: "create_list",
        tmdb_user_id: 123,
        operation_data: %{"name" => "My List", "description" => "Description"}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, valid_attrs)
      assert changeset.valid?

      # Invalid create_list data (missing name)
      invalid_attrs = %{
        operation_type: "create_list",
        tmdb_user_id: 123,
        operation_data: %{"description" => "Description"}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, invalid_attrs)
      refute changeset.valid?
      assert "invalid data for operation type" in errors_on(changeset).operation_data
    end

    test "validates operation_data for add_movie" do
      # Valid add_movie data
      valid_attrs = %{
        operation_type: "add_movie",
        tmdb_user_id: 123,
        tmdb_list_id: 456,
        operation_data: %{"movie_id" => 789}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, valid_attrs)
      assert changeset.valid?

      # Invalid add_movie data (missing movie_id)
      invalid_attrs = %{
        operation_type: "add_movie",
        tmdb_user_id: 123,
        tmdb_list_id: 456,
        operation_data: %{"other_field" => "value"}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, invalid_attrs)
      refute changeset.valid?
      assert "invalid data for operation type" in errors_on(changeset).operation_data
    end

    test "validates operation_data for remove_movie" do
      # Valid remove_movie data
      valid_attrs = %{
        operation_type: "remove_movie",
        tmdb_user_id: 123,
        tmdb_list_id: 456,
        operation_data: %{"movie_id" => 789}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, valid_attrs)
      assert changeset.valid?

      # Invalid remove_movie data (movie_id as string)
      invalid_attrs = %{
        operation_type: "remove_movie",
        tmdb_user_id: 123,
        tmdb_list_id: 456,
        operation_data: %{"movie_id" => "789"}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, invalid_attrs)
      refute changeset.valid?
      assert "invalid data for operation type" in errors_on(changeset).operation_data
    end

    test "validates operation_data for delete_list" do
      # Valid delete_list data (empty map is fine)
      valid_attrs = %{
        operation_type: "delete_list",
        tmdb_user_id: 123,
        tmdb_list_id: 456,
        operation_data: %{}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, valid_attrs)
      assert changeset.valid?
    end

    test "validates operation_data for clear_list" do
      # Valid clear_list data (empty map is fine)
      valid_attrs = %{
        operation_type: "clear_list",
        tmdb_user_id: 123,
        tmdb_list_id: 456,
        operation_data: %{}
      }

      changeset = QueuedOperation.changeset(%QueuedOperation{}, valid_attrs)
      assert changeset.valid?
    end
  end

  describe "retry_changeset/2" do
    test "valid retry changeset" do
      operation = %QueuedOperation{
        operation_type: "create_list",
        tmdb_user_id: 123,
        operation_data: %{"name" => "My List"},
        status: "failed",
        retry_count: 2
      }

      attrs = %{
        status: "pending",
        retry_count: 3,
        last_retry_at: DateTime.utc_now(),
        error_message: "Previous error",
        scheduled_for: DateTime.utc_now() |> DateTime.add(60, :second)
      }

      changeset = QueuedOperation.retry_changeset(operation, attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == "pending"
      assert get_change(changeset, :retry_count) == 3
    end

    test "invalid retry changeset with invalid status" do
      operation = %QueuedOperation{status: "failed"}
      attrs = %{status: "invalid_status"}

      changeset = QueuedOperation.retry_changeset(operation, attrs)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "invalid retry changeset with negative retry_count" do
      operation = %QueuedOperation{retry_count: 2}
      attrs = %{retry_count: -1}

      changeset = QueuedOperation.retry_changeset(operation, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).retry_count
    end
  end

  describe "operation_types/0" do
    test "returns list of valid operation types" do
      types = QueuedOperation.operation_types()

      assert "create_list" in types
      assert "update_list" in types
      assert "delete_list" in types
      assert "clear_list" in types
      assert "add_movie" in types
      assert "remove_movie" in types
    end
  end

  describe "statuses/0" do
    test "returns list of valid statuses" do
      statuses = QueuedOperation.statuses()

      assert "pending" in statuses
      assert "processing" in statuses
      assert "completed" in statuses
      assert "failed" in statuses
      assert "cancelled" in statuses
    end
  end
end
