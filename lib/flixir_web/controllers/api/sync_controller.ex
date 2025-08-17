defmodule FlixirWeb.Api.SyncController do
  use FlixirWeb, :controller

  alias Flixir.Lists
  alias Flixir.Lists.Cache

  action_fallback FlixirWeb.Api.FallbackController

  def sync_all_lists(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, sync_result} <- Lists.sync_all_user_lists(user.tmdb_user_id) do
      json(conn, %{
        message: "Sync completed successfully",
        synced_lists: sync_result.synced_count,
        failed_lists: sync_result.failed_count,
        errors: sync_result.errors,
        sync_timestamp: DateTime.utc_now()
      })
    else
      {:error, :tmdb_api_unavailable} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "TMDB API is currently unavailable"})

      {:error, :session_expired} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "TMDB session expired. Please re-authenticate."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Sync failed: #{inspect(reason)}"})
    end
  end

  def sync_list(conn, %{"tmdb_list_id" => tmdb_list_id}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, sync_result} <- Lists.sync_user_list(user.tmdb_user_id, list_id) do
      json(conn, %{
        message: "List synced successfully",
        list_id: list_id,
        items_synced: sync_result.items_count,
        last_modified: sync_result.last_modified,
        sync_timestamp: DateTime.utc_now()
      })
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid list ID format"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List not found"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})

      {:error, :tmdb_api_unavailable} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "TMDB API is currently unavailable"})

      {:error, :session_expired} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "TMDB session expired. Please re-authenticate."})
    end
  end

  def sync_status(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, status} <- Lists.get_sync_status(user.tmdb_user_id) do
      json(conn, %{
        sync_status: status.status,
        last_sync_at: status.last_sync_at,
        pending_operations: status.pending_operations,
        failed_operations: status.failed_operations,
        cache_status: %{
          cached_lists: status.cached_lists_count,
          cache_hit_rate: status.cache_hit_rate,
          oldest_cache_entry: status.oldest_cache_entry
        },
        tmdb_api_status: %{
          available: status.tmdb_api_available,
          last_successful_call: status.last_successful_tmdb_call,
          rate_limit_remaining: status.rate_limit_remaining
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
end
