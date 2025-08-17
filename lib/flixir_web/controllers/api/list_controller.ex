defmodule FlixirWeb.Api.ListController do
  use FlixirWeb, :controller

  alias Flixir.Lists
  alias Flixir.Auth

  action_fallback FlixirWeb.Api.FallbackController

  # Public API endpoints (no authentication required)

  def show_public(conn, %{"tmdb_list_id" => tmdb_list_id}) do
    with {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, list} <- Lists.get_public_list(list_id) do
      render(conn, :show, list: list)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid list ID format"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List not found"})

      {:error, :private_list} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "List is private"})
    end
  end

  def show_shared(conn, %{"tmdb_list_id" => tmdb_list_id}) do
    with {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, list} <- Lists.get_shared_list(list_id) do
      render(conn, :show, list: list)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid list ID format"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List not found"})

      {:error, :not_shared} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "List is not shared"})
    end
  end

  # Protected API endpoints (authentication required)

  def index(conn, _params) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, lists} <- Lists.get_user_lists(user.tmdb_user_id) do
      render(conn, :index, lists: lists)
    end
  end

  def show(conn, %{"tmdb_list_id" => tmdb_list_id}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, list} <- Lists.get_user_list(user.tmdb_user_id, list_id) do
      render(conn, :show, list: list)
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
    end
  end

  def create(conn, %{"list" => list_params}) do
    with {:ok, user} <- get_current_user(conn),
         {:ok, list} <- Lists.create_list(user.tmdb_user_id, list_params) do
      conn
      |> put_status(:created)
      |> render(:show, list: list)
    else
      {:error, :queued} ->
        conn
        |> put_status(:accepted)
        |> json(%{message: "List creation queued for processing", status: "queued"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end



  def delete(conn, %{"tmdb_list_id" => tmdb_list_id}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, _list} <- Lists.delete_list(user.tmdb_user_id, list_id) do
      send_resp(conn, :no_content, "")
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid list ID format"})

      {:error, :queued} ->
        conn
        |> put_status(:accepted)
        |> json(%{message: "List deletion queued for processing", status: "queued"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List not found"})
    end
  end

  def clear(conn, %{"tmdb_list_id" => tmdb_list_id}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, list} <- Lists.clear_list(user.tmdb_user_id, list_id) do
      render(conn, :show, list: list)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid list ID format"})

      {:error, :queued} ->
        conn
        |> put_status(:accepted)
        |> json(%{message: "List clear queued for processing", status: "queued"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List not found"})
    end
  end

  def add_movie(conn, %{"tmdb_list_id" => tmdb_list_id, "tmdb_movie_id" => tmdb_movie_id}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {movie_id, ""} <- Integer.parse(tmdb_movie_id),
         {:ok, list} <- Lists.add_movie_to_list(user.tmdb_user_id, list_id, movie_id) do
      render(conn, :show, list: list)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})

      {:error, :queued} ->
        conn
        |> put_status(:accepted)
        |> json(%{message: "Movie addition queued for processing", status: "queued"})

      {:error, :duplicate_movie} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "Movie already in list"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List or movie not found"})
    end
  end

  def remove_movie(conn, %{"tmdb_list_id" => tmdb_list_id, "tmdb_movie_id" => tmdb_movie_id}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {movie_id, ""} <- Integer.parse(tmdb_movie_id),
         {:ok, list} <- Lists.remove_movie_from_list(user.tmdb_user_id, list_id, movie_id) do
      render(conn, :show, list: list)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid ID format"})

      {:error, :queued} ->
        conn
        |> put_status(:accepted)
        |> json(%{message: "Movie removal queued for processing", status: "queued"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List or movie not found"})
    end
  end

  def share(conn, %{"tmdb_list_id" => tmdb_list_id, "share_settings" => share_settings}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, list} <- Lists.share_list(user.tmdb_user_id, list_id, share_settings) do
      render(conn, :show, list: list)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid list ID format"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List not found"})
    end
  end

  def update_privacy(conn, %{"tmdb_list_id" => tmdb_list_id, "is_public" => is_public}) do
    with {:ok, user} <- get_current_user(conn),
         {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, list} <- Lists.update_list_privacy(user.tmdb_user_id, list_id, is_public) do
      render(conn, :show, list: list)
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid list ID format"})

      {:error, :queued} ->
        conn
        |> put_status(:accepted)
        |> json(%{message: "Privacy update queued for processing", status: "queued"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "List not found"})
    end
  end

  # Private helper functions

  defp get_current_user(conn) do
    case conn.assigns[:current_user] do
      nil -> {:error, :unauthorized}
      user -> {:ok, user}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
