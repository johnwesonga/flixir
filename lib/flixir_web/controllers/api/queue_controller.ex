defmodule FlixirWeb.Api.QueueController do
  use FlixirWeb, :controller

  alias Flixir.Lists.Queue

  action_fallback FlixirWeb.Api.FallbackController

  def index(conn, params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, operations} <- Queue.get_user_operations(user.tmdb_user_id, params) do
      json(conn, %{
        operations: Enum.map(operations, &format_operation/1),
        pagination: %{
          page: Map.get(params, "page", 1),
          per_page: Map.get(params, "per_page", 20),
          total: length(operations)
        }
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  def retry_all(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, retry_result} <- Queue.retry_user_operations(user.tmdb_user_id) do
      json(conn, %{
        message: "Retry initiated for all failed operations",
        operations_retried: retry_result.retried_count,
        operations_skipped: retry_result.skipped_count,
        retry_timestamp: DateTime.utc_now()
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :no_failed_operations} ->
        json(conn, %{
          message: "No failed operations to retry",
          operations_retried: 0
        })
    end
  end

  def retry_operation(conn, %{"operation_id" => operation_id}) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, operation} <- Queue.retry_operation(user.tmdb_user_id, operation_id) do
      json(conn, %{
        message: "Operation retry initiated",
        operation: format_operation(operation),
        retry_timestamp: DateTime.utc_now()
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Operation not found"})

      {:error, :operation_not_retryable} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Operation cannot be retried"})
    end
  end

  def cancel_operation(conn, %{"operation_id" => operation_id}) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, _operation} <- Queue.cancel_operation(user.tmdb_user_id, operation_id) do
      json(conn, %{
        message: "Operation cancelled successfully",
        cancelled_at: DateTime.utc_now()
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Operation not found"})

      {:error, :operation_not_cancellable} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Operation cannot be cancelled"})
    end
  end

  def stats(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, stats} <- Queue.get_user_stats(user.tmdb_user_id) do
      json(conn, %{
        queue_stats: %{
          total_operations: stats.total_operations,
          pending_operations: stats.pending_operations,
          processing_operations: stats.processing_operations,
          completed_operations: stats.completed_operations,
          failed_operations: stats.failed_operations,
          cancelled_operations: stats.cancelled_operations
        },
        operation_types: stats.operation_types,
        recent_activity: %{
          operations_last_hour: stats.operations_last_hour,
          operations_last_day: stats.operations_last_day,
          average_processing_time: stats.average_processing_time
        },
        retry_stats: %{
          operations_with_retries: stats.operations_with_retries,
          average_retry_count: stats.average_retry_count,
          max_retry_count: stats.max_retry_count
        }
      })
    else
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
    end
  end

  # Private helper functions

  defp get_current_user(conn) do
    case conn.assigns[:current_user] do
      nil -> {:error, :unauthorized}
      user -> {:ok, user}
    end
  end

  defp format_operation(operation) do
    %{
      id: operation.id,
      operation_type: operation.operation_type,
      tmdb_list_id: operation.tmdb_list_id,
      operation_data: operation.operation_data,
      status: operation.status,
      retry_count: operation.retry_count,
      created_at: operation.created_at,
      last_retry_at: operation.last_retry_at,
      error_message: operation.error_message
    }
  end
end
