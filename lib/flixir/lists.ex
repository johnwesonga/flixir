defmodule Flixir.Lists do
  @moduledoc """
  Context for managing user movie lists.

  This context provides business logic for creating, reading, updating, and deleting
  user movie lists, as well as managing movies within those lists. It includes
  user authorization checks to ensure data isolation and proper access control.
  """

  import Ecto.Query, warn: false
  alias Flixir.Repo
  alias Flixir.Lists.{UserMovieList, UserMovieListItem}
  alias Flixir.Media

  require Logger

  # List Management Functions

  @doc """
  Creates a new movie list for a user.

  ## Parameters
  - tmdb_user_id: The TMDB user ID who owns the list
  - attrs: Map containing list attributes (name, description, is_public)

  ## Returns
  - {:ok, list} - Successfully created list
  - {:error, changeset} - Validation errors

  ## Examples
      iex> create_list(12345, %{name: "My Watchlist", description: "Movies to watch"})
      {:ok, %UserMovieList{}}

      iex> create_list(12345, %{name: ""})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_list(integer(), map()) :: {:ok, UserMovieList.t()} | {:error, Ecto.Changeset.t()}
  def create_list(tmdb_user_id, attrs) when is_integer(tmdb_user_id) and is_map(attrs) do
    Logger.info("Creating new movie list", %{
      tmdb_user_id: tmdb_user_id,
      list_name: Map.get(attrs, "name") || Map.get(attrs, :name)
    })

    # Normalize keys to strings and add tmdb_user_id
    attrs_with_user =
      attrs
      |> normalize_keys_to_strings()
      |> Map.put("tmdb_user_id", tmdb_user_id)

    %UserMovieList{}
    |> UserMovieList.changeset(attrs_with_user)
    |> Repo.insert()
    |> case do
      {:ok, list} ->
        Logger.info("Successfully created movie list", %{
          list_id: list.id,
          list_name: list.name,
          tmdb_user_id: tmdb_user_id
        })

        {:ok, list}

      {:error, changeset} ->
        Logger.warning("Failed to create movie list", %{
          tmdb_user_id: tmdb_user_id,
          errors: changeset.errors
        })

        {:error, changeset}
    end
  end

  @doc """
  Retrieves all movie lists for a specific user, ordered by most recently updated.

  ## Parameters
  - tmdb_user_id: The TMDB user ID

  ## Returns
  - List of UserMovieList structs with preloaded list_items

  ## Examples
      iex> get_user_lists(12345)
      [%UserMovieList{}, ...]
  """
  @spec get_user_lists(integer()) :: [UserMovieList.t()]
  def get_user_lists(tmdb_user_id) when is_integer(tmdb_user_id) do
    Logger.debug("Retrieving user lists", %{tmdb_user_id: tmdb_user_id})

    lists =
      from(l in UserMovieList,
        where: l.tmdb_user_id == ^tmdb_user_id,
        order_by: [desc: l.updated_at],
        preload: [:list_items]
      )
      |> Repo.all()

    Logger.debug("Retrieved user lists", %{
      tmdb_user_id: tmdb_user_id,
      count: length(lists)
    })

    lists
  end

  @doc """
  Retrieves a specific movie list by ID, ensuring the user has access to it.

  ## Parameters
  - list_id: The list UUID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, list} - List found and user authorized
  - {:error, :not_found} - List doesn't exist or user not authorized
  - {:error, :unauthorized} - User doesn't own the list

  ## Examples
      iex> get_list("uuid-123", 12345)
      {:ok, %UserMovieList{}}

      iex> get_list("nonexistent", 12345)
      {:error, :not_found}
  """
  @spec get_list(binary(), integer()) ::
          {:ok, UserMovieList.t()} | {:error, :not_found | :unauthorized}
  def get_list(list_id, tmdb_user_id) when is_binary(list_id) and is_integer(tmdb_user_id) do
    Logger.debug("Retrieving list", %{list_id: list_id, tmdb_user_id: tmdb_user_id})

    case Repo.get(UserMovieList, list_id) do
      nil ->
        Logger.debug("List not found", %{list_id: list_id})
        {:error, :not_found}

      %UserMovieList{tmdb_user_id: ^tmdb_user_id} = list ->
        list_with_items = Repo.preload(list, [:list_items])

        Logger.debug("List retrieved successfully", %{
          list_id: list_id,
          list_name: list.name,
          item_count: length(list_with_items.list_items)
        })

        {:ok, list_with_items}

      %UserMovieList{} ->
        Logger.warning("Unauthorized list access attempt", %{
          list_id: list_id,
          tmdb_user_id: tmdb_user_id
        })

        {:error, :unauthorized}
    end
  end

  @doc """
  Updates an existing movie list.

  ## Parameters
  - list: The UserMovieList struct to update
  - attrs: Map containing updated attributes

  ## Returns
  - {:ok, list} - Successfully updated list
  - {:error, changeset} - Validation errors

  ## Examples
      iex> update_list(list, %{name: "Updated Name"})
      {:ok, %UserMovieList{}}

      iex> update_list(list, %{name: ""})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_list(UserMovieList.t(), map()) ::
          {:ok, UserMovieList.t()} | {:error, Ecto.Changeset.t()}
  def update_list(%UserMovieList{} = list, attrs) when is_map(attrs) do
    Logger.info("Updating movie list", %{
      list_id: list.id,
      list_name: list.name,
      tmdb_user_id: list.tmdb_user_id
    })

    list
    |> UserMovieList.update_changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_list} ->
        Logger.info("Successfully updated movie list", %{
          list_id: updated_list.id,
          list_name: updated_list.name
        })

        {:ok, updated_list}

      {:error, changeset} ->
        Logger.warning("Failed to update movie list", %{
          list_id: list.id,
          errors: changeset.errors
        })

        {:error, changeset}
    end
  end

  @doc """
  Deletes a movie list and all its associated items.

  ## Parameters
  - list: The UserMovieList struct to delete

  ## Returns
  - {:ok, list} - Successfully deleted list
  - {:error, changeset} - Database error

  ## Examples
      iex> delete_list(list)
      {:ok, %UserMovieList{}}
  """
  @spec delete_list(UserMovieList.t()) :: {:ok, UserMovieList.t()} | {:error, Ecto.Changeset.t()}
  def delete_list(%UserMovieList{} = list) do
    Logger.info("Deleting movie list", %{
      list_id: list.id,
      list_name: list.name,
      tmdb_user_id: list.tmdb_user_id
    })

    case Repo.delete(list) do
      {:ok, deleted_list} ->
        Logger.info("Successfully deleted movie list", %{
          list_id: deleted_list.id,
          list_name: deleted_list.name
        })

        {:ok, deleted_list}

      {:error, changeset} ->
        Logger.error("Failed to delete movie list", %{
          list_id: list.id,
          errors: changeset.errors
        })

        {:error, changeset}
    end
  end

  @doc """
  Clears all movies from a list while preserving the list metadata.

  ## Parameters
  - list: The UserMovieList struct to clear

  ## Returns
  - {:ok, {count, nil}} - Number of items deleted
  - {:error, reason} - Database error

  ## Examples
      iex> clear_list(list)
      {:ok, {5, nil}}  # 5 movies removed
  """
  @spec clear_list(UserMovieList.t()) :: {:ok, {integer(), nil}} | {:error, term()}
  def clear_list(%UserMovieList{} = list) do
    Logger.info("Clearing movie list", %{
      list_id: list.id,
      list_name: list.name,
      tmdb_user_id: list.tmdb_user_id
    })

    query = from(item in UserMovieListItem, where: item.list_id == ^list.id)

    case Repo.delete_all(query) do
      {count, nil} = result ->
        Logger.info("Successfully cleared movie list", %{
          list_id: list.id,
          list_name: list.name,
          items_removed: count
        })

        {:ok, result}

      error ->
        Logger.error("Failed to clear movie list", %{
          list_id: list.id,
          error: inspect(error)
        })

        {:error, error}
    end
  end

  # Movie Management Functions

  @doc """
  Adds a movie to a user's list.

  ## Parameters
  - list_id: The list UUID
  - tmdb_movie_id: The TMDB movie ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, list_item} - Successfully added movie
  - {:error, reason} - Error occurred (unauthorized, not_found, duplicate, etc.)

  ## Examples
      iex> add_movie_to_list("uuid-123", 550, 12345)
      {:ok, %UserMovieListItem{}}

      iex> add_movie_to_list("uuid-123", 550, 12345)
      {:error, :duplicate_movie}
  """
  @spec add_movie_to_list(binary(), integer(), integer()) ::
          {:ok, UserMovieListItem.t()} | {:error, term()}
  def add_movie_to_list(list_id, tmdb_movie_id, tmdb_user_id)
      when is_binary(list_id) and is_integer(tmdb_movie_id) and is_integer(tmdb_user_id) do
    Logger.info("Adding movie to list", %{
      list_id: list_id,
      tmdb_movie_id: tmdb_movie_id,
      tmdb_user_id: tmdb_user_id
    })

    with {:ok, _list} <- get_list(list_id, tmdb_user_id),
         {:ok, list_item} <- create_list_item(list_id, tmdb_movie_id) do
      Logger.info("Successfully added movie to list", %{
        list_id: list_id,
        tmdb_movie_id: tmdb_movie_id,
        item_id: list_item.id
      })

      {:ok, list_item}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        # Check for unique constraint violation
        if Enum.any?(changeset.errors, fn {field, {_msg, opts}} ->
             field in [:tmdb_movie_id, :list_id] and Keyword.get(opts, :constraint) == :unique and
               Keyword.get(opts, :constraint_name) == "idx_unique_movie_per_list"
           end) do
          Logger.info("Attempted to add duplicate movie to list", %{
            list_id: list_id,
            tmdb_movie_id: tmdb_movie_id
          })

          {:error, :duplicate_movie}
        else
          Logger.error("Failed to add movie to list", %{
            list_id: list_id,
            tmdb_movie_id: tmdb_movie_id,
            errors: changeset.errors
          })

          {:error, :validation_error}
        end

      {:error, reason} = error ->
        Logger.error("Failed to add movie to list", %{
          list_id: list_id,
          tmdb_movie_id: tmdb_movie_id,
          reason: inspect(reason)
        })

        error
    end
  end

  @doc """
  Removes a movie from a user's list.

  ## Parameters
  - list_id: The list UUID
  - tmdb_movie_id: The TMDB movie ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, list_item} - Successfully removed movie
  - {:error, reason} - Error occurred (unauthorized, not_found, etc.)

  ## Examples
      iex> remove_movie_from_list("uuid-123", 550, 12345)
      {:ok, %UserMovieListItem{}}

      iex> remove_movie_from_list("uuid-123", 999, 12345)
      {:error, :not_found}
  """
  @spec remove_movie_from_list(binary(), integer(), integer()) ::
          {:ok, UserMovieListItem.t()} | {:error, term()}
  def remove_movie_from_list(list_id, tmdb_movie_id, tmdb_user_id)
      when is_binary(list_id) and is_integer(tmdb_movie_id) and is_integer(tmdb_user_id) do
    Logger.info("Removing movie from list", %{
      list_id: list_id,
      tmdb_movie_id: tmdb_movie_id,
      tmdb_user_id: tmdb_user_id
    })

    with {:ok, _list} <- get_list(list_id, tmdb_user_id),
         {:ok, list_item} <- get_list_item(list_id, tmdb_movie_id),
         {:ok, deleted_item} <- Repo.delete(list_item) do
      Logger.info("Successfully removed movie from list", %{
        list_id: list_id,
        tmdb_movie_id: tmdb_movie_id,
        item_id: deleted_item.id
      })

      {:ok, deleted_item}
    else
      {:error, reason} = error ->
        Logger.error("Failed to remove movie from list", %{
          list_id: list_id,
          tmdb_movie_id: tmdb_movie_id,
          reason: inspect(reason)
        })

        error
    end
  end

  @doc """
  Retrieves all movies in a list with their TMDB data.

  ## Parameters
  - list_id: The list UUID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, movies} - List of movie data with list metadata
  - {:error, reason} - Error occurred (unauthorized, not_found, etc.)

  ## Examples
      iex> get_list_movies("uuid-123", 12345)
      {:ok, [%{id: 550, title: "Fight Club", added_at: ~U[...], ...}, ...]}
  """
  @spec get_list_movies(binary(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_list_movies(list_id, tmdb_user_id)
      when is_binary(list_id) and is_integer(tmdb_user_id) do
    Logger.debug("Retrieving movies for list", %{
      list_id: list_id,
      tmdb_user_id: tmdb_user_id
    })

    with {:ok, list} <- get_list(list_id, tmdb_user_id) do
      movies =
        list.list_items
        |> Enum.map(fn item ->
          case Media.get_content_details(item.tmdb_movie_id, :movie) do
            {:ok, movie_data} ->
              movie_data
              |> Map.put("added_at", item.added_at)
              |> Map.put("list_id", list_id)

            {:error, reason} ->
              Logger.warning("Failed to fetch movie details", %{
                tmdb_movie_id: item.tmdb_movie_id,
                reason: inspect(reason)
              })

              # Return basic movie info if TMDB fetch fails
              %{
                "id" => item.tmdb_movie_id,
                "title" => "Movie ##{item.tmdb_movie_id}",
                "overview" => "Movie details unavailable",
                "poster_path" => nil,
                "release_date" => nil,
                "vote_average" => 0,
                "added_at" => item.added_at,
                "list_id" => list_id,
                "_error" => "Failed to load movie details"
              }
          end
        end)
        |> Enum.sort_by(& &1["added_at"], {:desc, DateTime})

      Logger.debug("Retrieved movies for list", %{
        list_id: list_id,
        movie_count: length(movies)
      })

      {:ok, movies}
    end
  end

  @doc """
  Checks if a movie is already in a specific list.

  ## Parameters
  - list_id: The list UUID
  - tmdb_movie_id: The TMDB movie ID

  ## Returns
  - true if movie is in list, false otherwise

  ## Examples
      iex> movie_in_list?("uuid-123", 550)
      true

      iex> movie_in_list?("uuid-123", 999)
      false
  """
  @spec movie_in_list?(binary(), integer()) :: boolean()
  def movie_in_list?(list_id, tmdb_movie_id)
      when is_binary(list_id) and is_integer(tmdb_movie_id) do
    query =
      from(item in UserMovieListItem,
        where: item.list_id == ^list_id and item.tmdb_movie_id == ^tmdb_movie_id,
        select: count(item.id)
      )

    Repo.one(query) > 0
  end

  # Statistics Functions

  @doc """
  Gets statistics for a specific list.

  ## Parameters
  - list_id: The list UUID

  ## Returns
  - Map containing list statistics

  ## Examples
      iex> get_list_stats("uuid-123")
      %{
        movie_count: 15,
        created_at: ~U[2024-01-01 12:00:00Z],
        updated_at: ~U[2024-01-02 15:30:00Z],
        is_public: false
      }
  """
  @spec get_list_stats(binary()) :: map()
  def get_list_stats(list_id) when is_binary(list_id) do
    Logger.debug("Getting list statistics", %{list_id: list_id})

    case Repo.get(UserMovieList, list_id) do
      nil ->
        %{error: :not_found}

      list ->
        movie_count =
          from(item in UserMovieListItem,
            where: item.list_id == ^list_id,
            select: count(item.id)
          )
          |> Repo.one()

        stats = %{
          movie_count: movie_count,
          created_at: list.inserted_at,
          updated_at: list.updated_at,
          is_public: list.is_public,
          name: list.name,
          description: list.description
        }

        Logger.debug("Retrieved list statistics", %{
          list_id: list_id,
          movie_count: movie_count
        })

        stats
    end
  end

  @doc """
  Gets summary statistics for all of a user's lists.

  ## Parameters
  - tmdb_user_id: The TMDB user ID

  ## Returns
  - Map containing user's list summary

  ## Examples
      iex> get_user_lists_summary(12345)
      %{
        total_lists: 5,
        total_movies: 47,
        public_lists: 2,
        private_lists: 3,
        most_recent_list: %UserMovieList{},
        largest_list: %{name: "Watchlist", movie_count: 25}
      }
  """
  @spec get_user_lists_summary(integer()) :: map()
  def get_user_lists_summary(tmdb_user_id) when is_integer(tmdb_user_id) do
    Logger.debug("Getting user lists summary", %{tmdb_user_id: tmdb_user_id})

    # Get basic list counts
    lists_query = from(l in UserMovieList, where: l.tmdb_user_id == ^tmdb_user_id)

    total_lists = Repo.aggregate(lists_query, :count, :id)
    public_lists = lists_query |> where([l], l.is_public == true) |> Repo.aggregate(:count, :id)
    private_lists = total_lists - public_lists

    # Get most recent list
    most_recent_list =
      lists_query
      |> order_by([l], desc: l.updated_at)
      |> limit(1)
      |> Repo.one()

    # Get total movies across all lists
    total_movies =
      from(item in UserMovieListItem,
        join: list in UserMovieList,
        on: item.list_id == list.id,
        where: list.tmdb_user_id == ^tmdb_user_id,
        select: count(item.id)
      )
      |> Repo.one()

    # Get largest list info
    largest_list =
      from(l in UserMovieList,
        left_join: item in UserMovieListItem,
        on: item.list_id == l.id,
        where: l.tmdb_user_id == ^tmdb_user_id,
        group_by: [l.id, l.name],
        select: %{name: l.name, movie_count: count(item.id)},
        order_by: [desc: count(item.id)],
        limit: 1
      )
      |> Repo.one()

    summary = %{
      total_lists: total_lists,
      total_movies: total_movies,
      public_lists: public_lists,
      private_lists: private_lists,
      most_recent_list: most_recent_list,
      largest_list: largest_list
    }

    Logger.debug("Retrieved user lists summary", %{
      tmdb_user_id: tmdb_user_id,
      total_lists: total_lists,
      total_movies: total_movies
    })

    summary
  end

  # Private helper functions

  defp create_list_item(list_id, tmdb_movie_id) do
    %UserMovieListItem{}
    |> UserMovieListItem.add_movie_changeset(%{
      list_id: list_id,
      tmdb_movie_id: tmdb_movie_id
    })
    |> Repo.insert()
  end

  defp get_list_item(list_id, tmdb_movie_id) do
    case Repo.get_by(UserMovieListItem, list_id: list_id, tmdb_movie_id: tmdb_movie_id) do
      nil -> {:error, :not_found}
      item -> {:ok, item}
    end
  end

  # Helper function to normalize map keys to strings
  defp normalize_keys_to_strings(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, Atom.to_string(key), value)
      {key, value}, acc when is_binary(key) -> Map.put(acc, key, value)
    end)
  end
end
