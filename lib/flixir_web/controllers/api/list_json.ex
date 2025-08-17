defmodule FlixirWeb.Api.ListJSON do
  @doc """
  Renders a list of lists.
  """
  def index(%{lists: lists}) do
    %{
      data: for(list <- lists, do: data(list)),
      meta: %{
        total: length(lists),
        timestamp: DateTime.utc_now()
      }
    }
  end

  @doc """
  Renders a single list.
  """
  def show(%{list: list}) do
    %{
      data: data(list),
      meta: %{
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp data(list) do
    %{
      tmdb_list_id: list.tmdb_list_id,
      name: list.name,
      description: list.description,
      is_public: list.is_public,
      item_count: list.item_count || 0,
      created_at: list.created_at,
      updated_at: list.updated_at,
      tmdb_url: build_tmdb_url(list.tmdb_list_id),
      share_url: build_share_url(list.tmdb_list_id, list.is_public),
      movies: format_movies(list.movies || []),
      sync_status: %{
        last_synced: list.last_synced_at,
        cache_status: list.cache_status || "unknown"
      }
    }
  end

  defp format_movies(movies) do
    Enum.map(movies, fn movie ->
      %{
        tmdb_movie_id: movie.tmdb_movie_id,
        title: movie.title,
        poster_path: movie.poster_path,
        release_date: movie.release_date,
        vote_average: movie.vote_average,
        added_at: movie.added_at
      }
    end)
  end

  defp build_tmdb_url(tmdb_list_id) do
    "https://www.themoviedb.org/list/#{tmdb_list_id}"
  end

  defp build_share_url(tmdb_list_id, is_public) do
    base_url = FlixirWeb.Endpoint.url()
    if is_public do
      "#{base_url}/lists/public/#{tmdb_list_id}"
    else
      "#{base_url}/lists/shared/#{tmdb_list_id}"
    end
  end
end
