defmodule Flixir.Lists.Queue do
  @moduledoc """
  Queue system for managing list operations when TMDB API is unavailable.

  Provides functionality to:
  - Queue operations for later processing
  - Process queued operations with retry logic
  - Handle operation deduplication and conflict resolution
  - Monitor queue status and provide manual retry capabilities
  """

  import Ecto.Query
  alias Flixir.Repo
  alias Flixir.Lists.{QueuedOperation, TMDBClient}
  alias Flixir.Auth

  require Logger

  @max_retries 5
  @base_delay_seconds 30
  @max_delay_seconds 3600  # 1 hour

  @doc """
  Enqueues an operation for later processing when TMDB API is unavailable.

  ## Parameters
  - operation_type: Type of operation (create_list, update_list, etc.)
  - tmdb_user_id: TMDB user ID
  - tmdb_list_id: TMDB list ID (optional for create operations)
  - operation_data: Data needed to perform the operation

  ## Examples
      iex> Queue.enqueue_operation("create_list", 123, nil, %{"name" => "My List"})
      {:ok, %QueuedOperation{}}

      iex> Queue.enqueue_operation("add_movie", 123, 456, %{"movie_id" => 789})
      {:ok, %QueuedOperation{}}
  """
  def enqueue_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data) do
    # Check for duplicate pending operations
    case find_duplicate_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data) do
      nil ->
        create_queued_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data)

      existing_operation ->
        Logger.info("Duplicate operation found, updating existing: #{existing_operation.id}")
        {:ok, existing_operation}
    end
  end

  @doc """
  Processes all pending operations in the queue.

  This function is typically called by a background job processor.
  """
  def process_pending_operations do
    pending_operations = get_pending_operations()

    Logger.info("Processing #{length(pending_operations)} pending operations")

    Enum.each(pending_operations, &process_operation/1)
  end

  @doc """
  Processes a specific queued operation.
  """
  def process_operation(%QueuedOperation{} = operation) do
    Logger.info("Processing operation #{operation.id} (#{operation.operation_type})")

    # Mark as processing
    {:ok, processing_operation} = update_operation_status(operation, "processing")

    case execute_operation(processing_operation) do
      {:ok, result} ->
        Logger.info("Operation #{operation.id} completed successfully")
        update_operation_status(processing_operation, "completed")
        {:ok, result}

      {:error, reason} ->
        Logger.warning("Operation #{operation.id} failed: #{inspect(reason)}")
        handle_operation_failure(processing_operation, reason)
    end
  end

  @doc """
  Retries a failed operation manually.
  """
  def retry_operation(operation_id) do
    case Repo.get(QueuedOperation, operation_id) do
      nil ->
        {:error, :not_found}

      %QueuedOperation{status: "failed"} = operation ->
        # Reset status and process
        operation
        |> QueuedOperation.retry_changeset(%{
          status: "pending",
          scheduled_for: DateTime.utc_now()
        })
        |> Repo.update()
        |> case do
          {:ok, updated_operation} ->
            process_operation(updated_operation)

          error ->
            error
        end

      %QueuedOperation{status: status} ->
        {:error, {:invalid_status, status}}
    end
  end

  @doc """
  Gets queue statistics for monitoring.
  """
  def get_queue_stats do
    stats_query = from(op in QueuedOperation,
      group_by: op.status,
      select: {op.status, count(op.id)}
    )

    stats = Repo.all(stats_query) |> Enum.into(%{})

    %{
      pending: Map.get(stats, "pending", 0),
      processing: Map.get(stats, "processing", 0),
      completed: Map.get(stats, "completed", 0),
      failed: Map.get(stats, "failed", 0),
      cancelled: Map.get(stats, "cancelled", 0),
      total: Enum.sum(Map.values(stats))
    }
  end

  @doc """
  Gets pending operations for a specific user.
  """
  def get_user_pending_operations(tmdb_user_id) do
    from(op in QueuedOperation,
      where: op.tmdb_user_id == ^tmdb_user_id and op.status in ["pending", "processing"],
      order_by: [asc: op.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets failed operations that can be retried.
  """
  def get_failed_operations(limit \\ 50) do
    from(op in QueuedOperation,
      where: op.status == "failed" and op.retry_count < ^@max_retries,
      order_by: [asc: op.last_retry_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Cancels a pending operation.
  """
  def cancel_operation(operation_id) do
    case Repo.get(QueuedOperation, operation_id) do
      nil ->
        {:error, :not_found}

      %QueuedOperation{status: status} = operation when status in ["pending", "processing"] ->
        operation
        |> QueuedOperation.retry_changeset(%{status: "cancelled"})
        |> Repo.update()

      %QueuedOperation{status: status} ->
        {:error, {:invalid_status, status}}
    end
  end

  @doc """
  Cleans up old completed and cancelled operations.
  """
  def cleanup_old_operations(days_old \\ 30) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_old, :day)

    from(op in QueuedOperation,
      where: op.status in ["completed", "cancelled"] and op.updated_at < ^cutoff_date
    )
    |> Repo.delete_all()
  end

  # Private functions

  defp create_queued_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data) do
    %QueuedOperation{}
    |> QueuedOperation.changeset(%{
      operation_type: operation_type,
      tmdb_user_id: tmdb_user_id,
      tmdb_list_id: tmdb_list_id,
      operation_data: operation_data,
      scheduled_for: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp find_duplicate_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data) do
    # For some operations, we want to prevent duplicates
    case operation_type do
      "create_list" ->
        # Don't duplicate list creation with same name
        list_name = Map.get(operation_data, "name")

        from(op in QueuedOperation,
          where: op.operation_type == "create_list" and
                 op.tmdb_user_id == ^tmdb_user_id and
                 op.status == "pending" and
                 fragment("?->>'name' = ?", op.operation_data, ^list_name)
        )
        |> Repo.one()

      "add_movie" ->
        # Don't duplicate adding same movie to same list
        movie_id = Map.get(operation_data, "movie_id")

        from(op in QueuedOperation,
          where: op.operation_type == "add_movie" and
                 op.tmdb_user_id == ^tmdb_user_id and
                 op.tmdb_list_id == ^tmdb_list_id and
                 op.status == "pending" and
                 fragment("?->>'movie_id' = ?", op.operation_data, ^to_string(movie_id))
        )
        |> Repo.one()

      "remove_movie" ->
        # Don't duplicate removing same movie from same list
        movie_id = Map.get(operation_data, "movie_id")

        from(op in QueuedOperation,
          where: op.operation_type == "remove_movie" and
                 op.tmdb_user_id == ^tmdb_user_id and
                 op.tmdb_list_id == ^tmdb_list_id and
                 op.status == "pending" and
                 fragment("?->>'movie_id' = ?", op.operation_data, ^to_string(movie_id))
        )
        |> Repo.one()

      _ ->
        # For other operations, allow duplicates
        nil
    end
  end

  defp get_pending_operations do
    now = DateTime.utc_now()

    from(op in QueuedOperation,
      where: op.status == "pending" and
             (is_nil(op.scheduled_for) or op.scheduled_for <= ^now),
      order_by: [asc: op.inserted_at]
    )
    |> Repo.all()
  end

  defp execute_operation(%QueuedOperation{} = operation) do
    case Auth.get_user_session(operation.tmdb_user_id) do
      {:ok, session_id} ->
        perform_tmdb_operation(operation, session_id)

      {:error, reason} ->
        {:error, {:auth_failed, reason}}
    end
  end

  defp perform_tmdb_operation(%QueuedOperation{operation_type: "create_list"} = operation, session_id) do
    TMDBClient.create_list(session_id, operation.operation_data)
  end

  defp perform_tmdb_operation(%QueuedOperation{operation_type: "update_list"} = operation, session_id) do
    TMDBClient.update_list(operation.tmdb_list_id, session_id, operation.operation_data)
  end

  defp perform_tmdb_operation(%QueuedOperation{operation_type: "delete_list"} = operation, session_id) do
    TMDBClient.delete_list(operation.tmdb_list_id, session_id)
  end

  defp perform_tmdb_operation(%QueuedOperation{operation_type: "clear_list"} = operation, session_id) do
    TMDBClient.clear_list(operation.tmdb_list_id, session_id)
  end

  defp perform_tmdb_operation(%QueuedOperation{operation_type: "add_movie"} = operation, session_id) do
    movie_id = Map.get(operation.operation_data, "movie_id")
    TMDBClient.add_movie_to_list(operation.tmdb_list_id, movie_id, session_id)
  end

  defp perform_tmdb_operation(%QueuedOperation{operation_type: "remove_movie"} = operation, session_id) do
    movie_id = Map.get(operation.operation_data, "movie_id")
    TMDBClient.remove_movie_from_list(operation.tmdb_list_id, movie_id, session_id)
  end

  defp handle_operation_failure(operation, reason) do
    new_retry_count = operation.retry_count + 1

    if new_retry_count >= @max_retries do
      # Mark as permanently failed
      operation
      |> QueuedOperation.retry_changeset(%{
        status: "failed",
        retry_count: new_retry_count,
        error_message: inspect(reason)
      })
      |> Repo.update()

      {:error, :max_retries_exceeded}
    else
      # Schedule for retry with exponential backoff
      delay_seconds = calculate_retry_delay(new_retry_count)
      scheduled_for = DateTime.utc_now() |> DateTime.add(delay_seconds, :second)

      operation
      |> QueuedOperation.retry_changeset(%{
        status: "pending",
        retry_count: new_retry_count,
        last_retry_at: DateTime.utc_now(),
        scheduled_for: scheduled_for,
        error_message: inspect(reason)
      })
      |> Repo.update()

      {:error, {:scheduled_retry, delay_seconds}}
    end
  end

  defp calculate_retry_delay(retry_count) do
    # Exponential backoff: base_delay * 2^(retry_count - 1)
    delay = @base_delay_seconds * :math.pow(2, retry_count - 1)
    min(trunc(delay), @max_delay_seconds)
  end

  defp update_operation_status(operation, status, error_message \\ nil) do
    attrs = %{status: status}
    attrs = if error_message, do: Map.put(attrs, :error_message, error_message), else: attrs

    operation
    |> QueuedOperation.retry_changeset(attrs)
    |> Repo.update()
  end
end
