defmodule FlixirWeb.Api.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use FlixirWeb, :controller

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: FlixirWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: FlixirWeb.ErrorHTML, json: FlixirWeb.ErrorJSON)
    |> render(:"404")
  end

  # Handle unauthorized access
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Authentication required"})
  end

  # Handle TMDB API specific errors
  def call(conn, {:error, :tmdb_api_unavailable}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{
      error: "TMDB API is currently unavailable",
      retry_after: 60,
      message: "Please try again later"
    })
  end

  def call(conn, {:error, :session_expired}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: "TMDB session expired",
      message: "Please re-authenticate with TMDB"
    })
  end

  def call(conn, {:error, :rate_limit_exceeded}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{
      error: "TMDB API rate limit exceeded",
      retry_after: 300,
      message: "Please wait before making more requests"
    })
  end

  def call(conn, {:error, :duplicate_movie}) do
    conn
    |> put_status(:conflict)
    |> json(%{
      error: "Movie already exists in list",
      message: "This movie is already in the specified list"
    })
  end

  def call(conn, {:error, :private_list}) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      error: "List is private",
      message: "This list is private and cannot be accessed"
    })
  end

  def call(conn, {:error, :not_shared}) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      error: "List is not shared",
      message: "This list is not shared and cannot be accessed"
    })
  end

  def call(conn, {:error, :network_error}) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{
      error: "Network error",
      message: "Unable to connect to TMDB API"
    })
  end

  # Handle queued operations
  def call(conn, {:error, :queued}) do
    conn
    |> put_status(:accepted)
    |> json(%{
      message: "Operation queued for processing",
      status: "queued"
    })
  end

  # Generic error handler
  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      error: "Internal server error",
      message: "An unexpected error occurred: #{reason}"
    })
  end

  def call(conn, {:error, reason}) when is_binary(reason) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      error: "Internal server error",
      message: reason
    })
  end
end
