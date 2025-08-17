defmodule FlixirWeb.ListController do
  use FlixirWeb, :controller

  alias Flixir.Lists

  def external_redirect(conn, %{"tmdb_list_id" => tmdb_list_id}) do
    with {list_id, ""} <- Integer.parse(tmdb_list_id),
         {:ok, external_url} <- Lists.get_tmdb_list_url(list_id) do
      redirect(conn, external: external_url)
    else
      :error ->
        conn
        |> put_flash(:error, "Invalid list ID format")
        |> redirect(to: ~p"/")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "List not found on TMDB")
        |> redirect(to: ~p"/")

      {:error, :private_list} ->
        conn
        |> put_flash(:error, "This list is private and cannot be accessed externally")
        |> redirect(to: ~p"/")
    end
  end
end
