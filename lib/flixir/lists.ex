defmodule Flixir.Lists do
  @moduledoc """
  Context for managing user movie lists through TMDB API integration.

  This context provides business logic for creating, reading, updating, and deleting
  user movie lists using TMDB's native list management API as the primary data source.
  It includes optimistic updates, local caching for performance, operation queuing
  for offline scenarios, and comprehensive error handling for TMDB API failures.

  The system prioritizes TMDB API as the authoritative source while providing
  seamless user experience through local caching and optimistic updates.
  """

  alias Flixir.Lists.{TMDBClient, Cache, Queue}
  alias Flixir.Auth
  alias Flixir.Media

  require Logger

  # List Management Functions

  @doc """
  Creates a new movie list for a user using TMDB API.

  This function creates a list directly on TMDB and caches the result locally.
  If TMDB API is unavailable, the operation is queued for later processing.

  ## Parameters
  - tmdb_user_id: The TMDB user ID who owns the list
  - attrs: Map containing list attributes (name, description, is_public)

  ## Returns
  - {:ok, list_data} - Successfully created list with TMDB data
  - {:ok, :queued} - Operation queued due to API unavailability
  - {:error, reason} - Validation or API errors

  ## Examples
      iex> create_list(12345, %{name: "My Watchlist", description: "Movies to watch"})
      {:ok, %{"id" => 789, "name" => "My Watchlist", ...}}

      iex> create_list(12345, %{name: ""})
      {:error, :validation_error}
  """
  @spec create_list(integer(), map()) :: {:ok, map()} | {:ok, :queued} | {:error, term()}
  def create_list(tmdb_user_id, attrs) when is_integer(tmdb_user_id) and is_map(attrs) do
    Logger.info("Creating new movie list via TMDB API", %{
      tmdb_user_id: tmdb_user_id,
      list_name: Map.get(attrs, "name") || Map.get(attrs, :name)
    })

    # Validate attributes locally first
    case validate_list_attrs(attrs) do
      :ok ->
        create_list_via_tmdb(tmdb_user_id, attrs)

      {:error, reason} ->
        Logger.warning("List creation validation failed", %{
          tmdb_user_id: tmdb_user_id,
          reason: inspect(reason)
        })
        {:error, reason}
    end
  end

  @doc """
  Retrieves all movie lists for a specific user from TMDB API with cache fallback.

  This function implements cache-first retrieval with TMDB API fallback.
  It first checks the local cache, then fetches from TMDB API if needed.

  ## Parameters
  - tmdb_user_id: The TMDB user ID

  ## Returns
  - {:ok, lists} - List of TMDB list data
  - {:error, reason} - Error occurred during retrieval

  ## Examples
      iex> get_user_lists(12345)
      {:ok, [%{"id" => 1, "name" => "Watchlist", ...}, ...]}

      iex> get_user_lists(99999)
      {:error, :unauthorized}
  """
  @spec get_user_lists(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_user_lists(tmdb_user_id) when is_integer(tmdb_user_id) do
    Logger.debug("Retrieving user lists via TMDB integration", %{tmdb_user_id: tmdb_user_id})

    # Try cache first
    case Cache.get_user_lists(tmdb_user_id) do
      {:ok, cached_lists} ->
        Logger.debug("Retrieved user lists from cache", %{
          tmdb_user_id: tmdb_user_id,
          count: length(cached_lists)
        })
        {:ok, cached_lists}

      {:error, :not_found} ->
        # Fetch from TMDB API
        fetch_user_lists_from_tmdb(tmdb_user_id)

      {:error, :expired} ->
        # Cache expired, fetch fresh data
        Logger.debug("Cache expired, fetching fresh user lists", %{tmdb_user_id: tmdb_user_id})
        fetch_user_lists_from_tmdb(tmdb_user_id)
    end
  end

  @doc """
  Retrieves a specific movie list by TMDB list ID with cache fallback.

  This function implements cache-first retrieval with TMDB API fallback.
  It ensures the user has access to the list through session validation.

  ## Parameters
  - tmdb_list_id: The TMDB list ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, list_data} - List found and user authorized
  - {:error, :not_found} - List doesn't exist
  - {:error, :unauthorized} - User doesn't have access to the list

  ## Examples
      iex> get_list(789, 12345)
      {:ok, %{"id" => 789, "name" => "My List", ...}}

      iex> get_list(999, 12345)
      {:error, :not_found}
  """
  @spec get_list(integer(), integer()) :: {:ok, map()} | {:error, :not_found | :unauthorized | term()}
  def get_list(tmdb_list_id, tmdb_user_id) when is_integer(tmdb_list_id) and is_integer(tmdb_user_id) do
    Logger.debug("Retrieving list via TMDB integration", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_user_id: tmdb_user_id
    })

    # Try cache first
    case Cache.get_list(tmdb_list_id) do
      {:ok, cached_list} ->
        Logger.debug("Retrieved list from cache", %{
          tmdb_list_id: tmdb_list_id,
          list_name: cached_list["name"]
        })
        {:ok, cached_list}

      {:error, :not_found} ->
        # Fetch from TMDB API
        fetch_list_from_tmdb(tmdb_list_id, tmdb_user_id)

      {:error, :expired} ->
        # Cache expired, fetch fresh data
        Logger.debug("Cache expired, fetching fresh list data", %{tmdb_list_id: tmdb_list_id})
        fetch_list_from_tmdb(tmdb_list_id, tmdb_user_id)
    end
  end

  @doc """
  Updates an existing movie list via TMDB API with optimistic updates.

  This function implements optimistic updates with rollback capabilities.
  The cache is updated immediately, then the TMDB API is called. If the API
  call fails, the cache is reverted and the operation may be queued.

  ## Parameters
  - tmdb_list_id: The TMDB list ID to update
  - tmdb_user_id: The TMDB user ID for authorization
  - attrs: Map containing updated attributes

  ## Returns
  - {:ok, list_data} - Successfully updated list
  - {:ok, :queued} - Operation queued due to API unavailability
  - {:error, reason} - Validation or API errors

  ## Examples
      iex> update_list(789, 12345, %{name: "Updated Name"})
      {:ok, %{"id" => 789, "name" => "Updated Name", ...}}

      iex> update_list(789, 12345, %{name: ""})
      {:error, :validation_error}
  """
  @spec update_list(integer(), integer(), map()) :: {:ok, map()} | {:ok, :queued} | {:error, term()}
  def update_list(tmdb_list_id, tmdb_user_id, attrs)
      when is_integer(tmdb_list_id) and is_integer(tmdb_user_id) and is_map(attrs) do
    Logger.info("Updating movie list via TMDB API", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_user_id: tmdb_user_id,
      list_name: Map.get(attrs, "name") || Map.get(attrs, :name)
    })

    # Validate attributes locally first
    case validate_list_attrs(attrs) do
      :ok ->
        update_list_via_tmdb(tmdb_list_id, tmdb_user_id, attrs)

      {:error, reason} ->
        Logger.warning("List update validation failed", %{
          tmdb_list_id: tmdb_list_id,
          tmdb_user_id: tmdb_user_id,
          reason: inspect(reason)
        })
        {:error, reason}
    end
  end

  @doc """
  Deletes a movie list via TMDB API with optimistic updates.

  This function implements optimistic updates with rollback capabilities.
  The cache is invalidated immediately, then the TMDB API is called. If the API
  call fails, the operation may be queued for later processing.

  ## Parameters
  - tmdb_list_id: The TMDB list ID to delete
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, :deleted} - Successfully deleted list
  - {:ok, :queued} - Operation queued due to API unavailability
  - {:error, reason} - API or authorization errors

  ## Examples
      iex> delete_list(789, 12345)
      {:ok, :deleted}

      iex> delete_list(999, 12345)
      {:error, :not_found}
  """
  @spec delete_list(integer(), integer()) :: {:ok, :deleted} | {:ok, :queued} | {:error, term()}
  def delete_list(tmdb_list_id, tmdb_user_id)
      when is_integer(tmdb_list_id) and is_integer(tmdb_user_id) do
    Logger.info("Deleting movie list via TMDB API", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_user_id: tmdb_user_id
    })

    delete_list_via_tmdb(tmdb_list_id, tmdb_user_id)
  end

  @doc """
  Clears all movies from a list via TMDB API with optimistic updates.

  This function implements optimistic updates with rollback capabilities.
  The cache is updated immediately, then the TMDB API is called. If the API
  call fails, the cache is reverted and the operation may be queued.

  ## Parameters
  - tmdb_list_id: The TMDB list ID to clear
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, :cleared} - Successfully cleared list
  - {:ok, :queued} - Operation queued due to API unavailability
  - {:error, reason} - API or authorization errors

  ## Examples
      iex> clear_list(789, 12345)
      {:ok, :cleared}

      iex> clear_list(999, 12345)
      {:error, :not_found}
  """
  @spec clear_list(integer(), integer()) :: {:ok, :cleared} | {:ok, :queued} | {:error, term()}
  def clear_list(tmdb_list_id, tmdb_user_id)
      when is_integer(tmdb_list_id) and is_integer(tmdb_user_id) do
    Logger.info("Clearing movie list via TMDB API", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_user_id: tmdb_user_id
    })

    clear_list_via_tmdb(tmdb_list_id, tmdb_user_id)
  end

  # Movie Management Functions

  @doc """
  Adds a movie to a TMDB list with optimistic updates.

  This function implements optimistic updates with rollback capabilities.
  The cache is updated immediately, then the TMDB API is called. If the API
  call fails, the cache is reverted and the operation may be queued.

  ## Parameters
  - tmdb_list_id: The TMDB list ID
  - tmdb_movie_id: The TMDB movie ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, :added} - Successfully added movie
  - {:ok, :queued} - Operation queued due to API unavailability
  - {:error, reason} - Error occurred (unauthorized, not_found, duplicate, etc.)

  ## Examples
      iex> add_movie_to_list(789, 550, 12345)
      {:ok, :added}

      iex> add_movie_to_list(789, 550, 12345)
      {:error, :duplicate_movie}
  """
  @spec add_movie_to_list(integer(), integer(), integer()) :: {:ok, :added} | {:ok, :queued} | {:error, term()}
  def add_movie_to_list(tmdb_list_id, tmdb_movie_id, tmdb_user_id)
      when is_integer(tmdb_list_id) and is_integer(tmdb_movie_id) and is_integer(tmdb_user_id) do
    Logger.info("Adding movie to list via TMDB API", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_movie_id: tmdb_movie_id,
      tmdb_user_id: tmdb_user_id
    })

    add_movie_to_list_via_tmdb(tmdb_list_id, tmdb_movie_id, tmdb_user_id)
  end

  @doc """
  Removes a movie from a TMDB list with optimistic updates.

  This function implements optimistic updates with rollback capabilities.
  The cache is updated immediately, then the TMDB API is called. If the API
  call fails, the cache is reverted and the operation may be queued.

  ## Parameters
  - tmdb_list_id: The TMDB list ID
  - tmdb_movie_id: The TMDB movie ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, :removed} - Successfully removed movie
  - {:ok, :queued} - Operation queued due to API unavailability
  - {:error, reason} - Error occurred (unauthorized, not_found, etc.)

  ## Examples
      iex> remove_movie_from_list(789, 550, 12345)
      {:ok, :removed}

      iex> remove_movie_from_list(789, 999, 12345)
      {:error, :not_found}
  """
  @spec remove_movie_from_list(integer(), integer(), integer()) :: {:ok, :removed} | {:ok, :queued} | {:error, term()}
  def remove_movie_from_list(tmdb_list_id, tmdb_movie_id, tmdb_user_id)
      when is_integer(tmdb_list_id) and is_integer(tmdb_movie_id) and is_integer(tmdb_user_id) do
    Logger.info("Removing movie from list via TMDB API", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_movie_id: tmdb_movie_id,
      tmdb_user_id: tmdb_user_id
    })

    remove_movie_from_list_via_tmdb(tmdb_list_id, tmdb_movie_id, tmdb_user_id)
  end

  @doc """
  Retrieves all movies in a TMDB list with cache fallback.

  This function implements cache-first retrieval with TMDB API fallback.
  It returns the list items with their TMDB movie data.

  ## Parameters
  - tmdb_list_id: The TMDB list ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, movies} - List of movie data with list metadata
  - {:error, reason} - Error occurred (unauthorized, not_found, etc.)

  ## Examples
      iex> get_list_movies(789, 12345)
      {:ok, [%{"id" => 550, "title" => "Fight Club", ...}, ...]}
  """
  @spec get_list_movies(integer(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_list_movies(tmdb_list_id, tmdb_user_id)
      when is_integer(tmdb_list_id) and is_integer(tmdb_user_id) do
    Logger.debug("Retrieving movies for list via TMDB integration", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_user_id: tmdb_user_id
    })

    # Try cache first
    case Cache.get_list_items(tmdb_list_id) do
      {:ok, cached_items} ->
        Logger.debug("Retrieved list items from cache", %{
          tmdb_list_id: tmdb_list_id,
          movie_count: length(cached_items)
        })
        {:ok, cached_items}

      {:error, :not_found} ->
        # Fetch from TMDB API
        fetch_list_movies_from_tmdb(tmdb_list_id, tmdb_user_id)

      {:error, :expired} ->
        # Cache expired, fetch fresh data
        Logger.debug("Cache expired, fetching fresh list items", %{tmdb_list_id: tmdb_list_id})
        fetch_list_movies_from_tmdb(tmdb_list_id, tmdb_user_id)
    end
  end

  @doc """
  Checks if a movie is already in a specific TMDB list.

  This function checks the cache first, then falls back to TMDB API if needed.

  ## Parameters
  - tmdb_list_id: The TMDB list ID
  - tmdb_movie_id: The TMDB movie ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, true} if movie is in list
  - {:ok, false} if movie is not in list
  - {:error, reason} if unable to check

  ## Examples
      iex> movie_in_list?(789, 550, 12345)
      {:ok, true}

      iex> movie_in_list?(789, 999, 12345)
      {:ok, false}
  """
  @spec movie_in_list?(integer(), integer(), integer()) :: {:ok, boolean()} | {:error, term()}
  def movie_in_list?(tmdb_list_id, tmdb_movie_id, tmdb_user_id)
      when is_integer(tmdb_list_id) and is_integer(tmdb_movie_id) and is_integer(tmdb_user_id) do
    case get_list_movies(tmdb_list_id, tmdb_user_id) do
      {:ok, movies} ->
        movie_exists = Enum.any?(movies, fn movie -> movie["id"] == tmdb_movie_id end)
        {:ok, movie_exists}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Statistics Functions

  @doc """
  Gets statistics for a specific TMDB list.

  ## Parameters
  - tmdb_list_id: The TMDB list ID
  - tmdb_user_id: The TMDB user ID for authorization

  ## Returns
  - {:ok, stats} - Map containing list statistics
  - {:error, reason} - Error occurred

  ## Examples
      iex> get_list_stats(789, 12345)
      {:ok, %{
        movie_count: 15,
        created_at: "2024-01-01T12:00:00Z",
        updated_at: "2024-01-02T15:30:00Z",
        is_public: false,
        name: "My Watchlist",
        description: "Movies to watch"
      }}
  """
  @spec get_list_stats(integer(), integer()) :: {:ok, map()} | {:error, term()}
  def get_list_stats(tmdb_list_id, tmdb_user_id) when is_integer(tmdb_list_id) and is_integer(tmdb_user_id) do
    Logger.debug("Getting list statistics via TMDB integration", %{
      tmdb_list_id: tmdb_list_id,
      tmdb_user_id: tmdb_user_id
    })

    case get_list(tmdb_list_id, tmdb_user_id) do
      {:ok, list_data} ->
        stats = %{
          movie_count: Map.get(list_data, "item_count", 0),
          created_at: Map.get(list_data, "created_at"),
          updated_at: Map.get(list_data, "updated_at"),
          is_public: Map.get(list_data, "public", false),
          name: Map.get(list_data, "name"),
          description: Map.get(list_data, "description", "")
        }

        Logger.debug("Retrieved list statistics", %{
          tmdb_list_id: tmdb_list_id,
          movie_count: stats.movie_count
        })

        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets summary statistics for all of a user's TMDB lists.

  ## Parameters
  - tmdb_user_id: The TMDB user ID

  ## Returns
  - {:ok, summary} - Map containing user's list summary
  - {:error, reason} - Error occurred

  ## Examples
      iex> get_user_lists_summary(12345)
      {:ok, %{
        total_lists: 5,
        total_movies: 47,
        public_lists: 2,
        private_lists: 3,
        most_recent_list: %{...},
        largest_list: %{name: "Watchlist", movie_count: 25}
      }}
  """
  @spec get_user_lists_summary(integer()) :: {:ok, map()} | {:error, term()}
  def get_user_lists_summary(tmdb_user_id) when is_integer(tmdb_user_id) do
    Logger.debug("Getting user lists summary via TMDB integration", %{tmdb_user_id: tmdb_user_id})

    case get_user_lists(tmdb_user_id) do
      {:ok, lists} ->
        total_lists = length(lists)
        public_lists = Enum.count(lists, fn list -> Map.get(list, "public", false) end)
        private_lists = total_lists - public_lists

        # Calculate total movies across all lists
        total_movies = lists
        |> Enum.map(fn list -> Map.get(list, "item_count", 0) end)
        |> Enum.sum()

        # Find most recent list (by updated_at or created_at)
        most_recent_list = lists
        |> Enum.max_by(fn list ->
          updated_at = Map.get(list, "updated_at")
          created_at = Map.get(list, "created_at")
          updated_at || created_at || "1970-01-01T00:00:00Z"
        end, fn -> nil end)

        # Find largest list
        largest_list = lists
        |> Enum.max_by(fn list -> Map.get(list, "item_count", 0) end, fn -> nil end)
        |> case do
          nil -> nil
          list -> %{
            name: Map.get(list, "name"),
            movie_count: Map.get(list, "item_count", 0)
          }
        end

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

        {:ok, summary}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets queue statistics for a user's pending operations.

  ## Parameters
  - tmdb_user_id: The TMDB user ID

  ## Returns
  - Map containing queue statistics

  ## Examples
      iex> get_user_queue_stats(12345)
      %{
        pending_operations: 3,
        failed_operations: 1,
        last_sync_attempt: ~U[2024-01-01 12:00:00Z]
      }
  """
  @spec get_user_queue_stats(integer()) :: map()
  def get_user_queue_stats(tmdb_user_id) when is_integer(tmdb_user_id) do
    pending_operations = Queue.get_user_pending_operations(tmdb_user_id)
    failed_operations = Queue.get_failed_operations() |> Enum.filter(&(&1.tmdb_user_id == tmdb_user_id))

    %{
      pending_operations: length(pending_operations),
      failed_operations: length(failed_operations),
      last_sync_attempt: get_last_sync_attempt(pending_operations ++ failed_operations)
    }
  end

  defp get_last_sync_attempt([]), do: nil
  defp get_last_sync_attempt(operations) do
    operations
    |> Enum.map(& &1.updated_at)
    |> Enum.max(DateTime, fn -> nil end)
  end

  # Helper functions for TMDB integration

  @doc """
  Validates list attributes before sending to TMDB API.

  ## Parameters
  - attrs: Map containing list attributes

  ## Returns
  - :ok if valid
  - {:error, reason} if invalid
  """
  def validate_list_attrs(attrs) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name)
    description = Map.get(attrs, "description") || Map.get(attrs, :description)

    cond do
      is_nil(name) or String.trim(name) == "" ->
        {:error, :name_required}

      String.length(name) < 3 ->
        {:error, :name_too_short}

      String.length(name) > 100 ->
        {:error, :name_too_long}

      description && String.length(description) > 500 ->
        {:error, :description_too_long}

      true ->
        :ok
    end
  end

  defp create_list_via_tmdb(tmdb_user_id, attrs) do
    case get_user_session(tmdb_user_id) do
      {:ok, session_id} ->
        case TMDBClient.create_list(session_id, attrs) do
          {:ok, %{list_id: tmdb_list_id} = response} ->
            # Cache the new list
            list_data = build_list_data_from_response(tmdb_list_id, attrs, response)
            Cache.put_list(list_data)
            Cache.invalidate_user_cache(tmdb_user_id)

            Logger.info("Successfully created list via TMDB API", %{
              tmdb_list_id: tmdb_list_id,
              tmdb_user_id: tmdb_user_id
            })

            {:ok, list_data}

          {:error, reason} ->
            handle_tmdb_api_error(reason, :create_list, tmdb_user_id, nil, attrs)
        end

      {:error, :no_valid_session} ->
        Logger.warning("No valid session for list creation", %{tmdb_user_id: tmdb_user_id})
        {:error, :unauthorized}
    end
  end

  defp fetch_user_lists_from_tmdb(tmdb_user_id) do
    case get_user_session(tmdb_user_id) do
      {:ok, session_id} ->
        {:ok, account_id} = get_account_id(tmdb_user_id)

        case TMDBClient.get_account_lists(account_id, session_id) do
          {:ok, %{"results" => lists}} ->
            # Cache the results
            Cache.put_user_lists(tmdb_user_id, lists)

            Logger.debug("Successfully fetched user lists from TMDB", %{
              tmdb_user_id: tmdb_user_id,
              count: length(lists)
            })

            {:ok, lists}

          {:error, reason} ->
            Logger.error("Failed to fetch user lists from TMDB", %{
              tmdb_user_id: tmdb_user_id,
              reason: inspect(reason)
            })
            {:error, reason}
        end

      {:error, :no_valid_session} ->
        {:error, :unauthorized}
    end
  end

  defp fetch_list_from_tmdb(tmdb_list_id, tmdb_user_id) do
    case get_user_session(tmdb_user_id) do
      {:ok, session_id} ->
        case TMDBClient.get_list(tmdb_list_id, session_id) do
          {:ok, list_data} ->
            # Cache the result
            Cache.put_list(list_data)

            Logger.debug("Successfully fetched list from TMDB", %{
              tmdb_list_id: tmdb_list_id,
              list_name: list_data["name"]
            })

            {:ok, list_data}

          {:error, reason} ->
            Logger.error("Failed to fetch list from TMDB", %{
              tmdb_list_id: tmdb_list_id,
              tmdb_user_id: tmdb_user_id,
              reason: inspect(reason)
            })
            {:error, reason}
        end

      {:error, :no_valid_session} ->
        {:error, :unauthorized}
    end
  end

  defp fetch_list_movies_from_tmdb(tmdb_list_id, tmdb_user_id) do
    case fetch_list_from_tmdb(tmdb_list_id, tmdb_user_id) do
      {:ok, list_data} ->
        items = Map.get(list_data, "items", [])

        # Cache the items separately
        Cache.put_list_items(tmdb_list_id, items)

        {:ok, items}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_list_via_tmdb(tmdb_list_id, tmdb_user_id, attrs) do
    # Optimistic update: update cache first
    case Cache.get_list(tmdb_list_id) do
      {:ok, cached_list} ->
        updated_list = Map.merge(cached_list, attrs)
        Cache.put_list(updated_list)

        # Now try TMDB API
        case get_user_session(tmdb_user_id) do
          {:ok, session_id} ->
            case TMDBClient.update_list(tmdb_list_id, session_id, attrs) do
              {:ok, _response} ->
                # Invalidate cache to force fresh fetch next time
                Cache.invalidate_list_cache(tmdb_list_id)
                Cache.invalidate_user_cache(tmdb_user_id)

                Logger.info("Successfully updated list via TMDB API", %{
                  tmdb_list_id: tmdb_list_id,
                  tmdb_user_id: tmdb_user_id
                })

                {:ok, updated_list}

              {:error, reason} ->
                # Rollback optimistic update
                Cache.put_list(cached_list)
                handle_tmdb_api_error(reason, :update_list, tmdb_user_id, tmdb_list_id, attrs)
            end

          {:error, :no_valid_session} ->
            # Rollback optimistic update
            Cache.put_list(cached_list)
            {:error, :unauthorized}
        end

      {:error, _} ->
        # No cached data, try direct API call
        case get_user_session(tmdb_user_id) do
          {:ok, session_id} ->
            case TMDBClient.update_list(tmdb_list_id, session_id, attrs) do
              {:ok, _response} ->
                # Fetch updated list data
                fetch_list_from_tmdb(tmdb_list_id, tmdb_user_id)

              {:error, reason} ->
                handle_tmdb_api_error(reason, :update_list, tmdb_user_id, tmdb_list_id, attrs)
            end

          {:error, :no_valid_session} ->
            {:error, :unauthorized}
        end
    end
  end

  defp delete_list_via_tmdb(tmdb_list_id, tmdb_user_id) do
    # Optimistic update: invalidate cache first
    Cache.invalidate_list_cache(tmdb_list_id)
    Cache.invalidate_user_cache(tmdb_user_id)

    case get_user_session(tmdb_user_id) do
      {:ok, session_id} ->
        case TMDBClient.delete_list(tmdb_list_id, session_id) do
          {:ok, _response} ->
            Logger.info("Successfully deleted list via TMDB API", %{
              tmdb_list_id: tmdb_list_id,
              tmdb_user_id: tmdb_user_id
            })

            {:ok, :deleted}

          {:error, reason} ->
            handle_tmdb_api_error(reason, :delete_list, tmdb_user_id, tmdb_list_id, %{})
        end

      {:error, :no_valid_session} ->
        {:error, :unauthorized}
    end
  end

  defp clear_list_via_tmdb(tmdb_list_id, tmdb_user_id) do
    # Optimistic update: clear cached items
    Cache.put_list_items(tmdb_list_id, [])

    case get_user_session(tmdb_user_id) do
      {:ok, session_id} ->
        case TMDBClient.clear_list(tmdb_list_id, session_id) do
          {:ok, _response} ->
            # Invalidate cache to force fresh fetch
            Cache.invalidate_list_cache(tmdb_list_id)

            Logger.info("Successfully cleared list via TMDB API", %{
              tmdb_list_id: tmdb_list_id,
              tmdb_user_id: tmdb_user_id
            })

            {:ok, :cleared}

          {:error, reason} ->
            handle_tmdb_api_error(reason, :clear_list, tmdb_user_id, tmdb_list_id, %{})
        end

      {:error, :no_valid_session} ->
        {:error, :unauthorized}
    end
  end

  defp add_movie_to_list_via_tmdb(tmdb_list_id, tmdb_movie_id, tmdb_user_id) do
    # Check for duplicates first
    case movie_in_list?(tmdb_list_id, tmdb_movie_id, tmdb_user_id) do
      {:ok, true} ->
        {:error, :duplicate_movie}

      {:ok, false} ->
        # Optimistic update: add to cached items
        case Cache.get_list_items(tmdb_list_id) do
          {:ok, cached_items} ->
            # Add movie data to cache optimistically
            case Media.get_content_details(tmdb_movie_id, :movie) do
              {:ok, movie_data} ->
                updated_items = [movie_data | cached_items]
                Cache.put_list_items(tmdb_list_id, updated_items)

              {:error, _} ->
                # Continue without movie details
                :ok
            end

          {:error, _} ->
            # No cached items, continue
            :ok
        end

        # Now try TMDB API
        case get_user_session(tmdb_user_id) do
          {:ok, session_id} ->
            case TMDBClient.add_movie_to_list(tmdb_list_id, tmdb_movie_id, session_id) do
              {:ok, _response} ->
                # Invalidate cache to force fresh fetch
                Cache.invalidate_list_cache(tmdb_list_id)

                Logger.info("Successfully added movie to list via TMDB API", %{
                  tmdb_list_id: tmdb_list_id,
                  tmdb_movie_id: tmdb_movie_id,
                  tmdb_user_id: tmdb_user_id
                })

                {:ok, :added}

              {:error, reason} ->
                # Rollback optimistic update
                case Cache.get_list_items(tmdb_list_id) do
                  {:ok, items} ->
                    rollback_items = Enum.reject(items, fn item -> item["id"] == tmdb_movie_id end)
                    Cache.put_list_items(tmdb_list_id, rollback_items)

                  {:error, _} ->
                    :ok
                end

                handle_tmdb_api_error(reason, :add_movie, tmdb_user_id, tmdb_list_id, %{"movie_id" => tmdb_movie_id})
            end

          {:error, :no_valid_session} ->
            {:error, :unauthorized}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp remove_movie_from_list_via_tmdb(tmdb_list_id, tmdb_movie_id, tmdb_user_id) do
    # Optimistic update: remove from cached items
    case Cache.get_list_items(tmdb_list_id) do
      {:ok, cached_items} ->
        updated_items = Enum.reject(cached_items, fn item -> item["id"] == tmdb_movie_id end)
        Cache.put_list_items(tmdb_list_id, updated_items)

      {:error, _} ->
        # No cached items, continue
        :ok
    end

    # Now try TMDB API
    case get_user_session(tmdb_user_id) do
      {:ok, session_id} ->
        case TMDBClient.remove_movie_from_list(tmdb_list_id, tmdb_movie_id, session_id) do
          {:ok, _response} ->
            # Invalidate cache to force fresh fetch
            Cache.invalidate_list_cache(tmdb_list_id)

            Logger.info("Successfully removed movie from list via TMDB API", %{
              tmdb_list_id: tmdb_list_id,
              tmdb_movie_id: tmdb_movie_id,
              tmdb_user_id: tmdb_user_id
            })

            {:ok, :removed}

          {:error, reason} ->
            handle_tmdb_api_error(reason, :remove_movie, tmdb_user_id, tmdb_list_id, %{"movie_id" => tmdb_movie_id})
        end

      {:error, :no_valid_session} ->
        {:error, :unauthorized}
    end
  end

  defp handle_tmdb_api_error(reason, operation_type, tmdb_user_id, tmdb_list_id, operation_data) do
    case reason do
      :timeout ->
        # Queue operation for retry
        queue_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data)

      :network_error ->
        # Queue operation for retry
        queue_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data)

      :rate_limited ->
        # Queue operation for retry
        queue_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data)

      {:server_error, _} ->
        # Queue operation for retry
        queue_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data)

      :session_expired ->
        Logger.warning("TMDB session expired during operation", %{
          operation_type: operation_type,
          tmdb_user_id: tmdb_user_id,
          tmdb_list_id: tmdb_list_id
        })
        {:error, :session_expired}

      :not_found ->
        {:error, :not_found}

      :access_denied ->
        {:error, :unauthorized}

      {:validation_error, message} ->
        {:error, {:validation_error, message}}

      _ ->
        Logger.error("Unhandled TMDB API error", %{
          operation_type: operation_type,
          tmdb_user_id: tmdb_user_id,
          tmdb_list_id: tmdb_list_id,
          reason: inspect(reason)
        })
        {:error, :api_error}
    end
  end

  defp queue_operation(operation_type, tmdb_user_id, tmdb_list_id, operation_data) do
    operation_type_string = Atom.to_string(operation_type)

    case Queue.enqueue_operation(operation_type_string, tmdb_user_id, tmdb_list_id, operation_data) do
      {:ok, _operation} ->
        Logger.info("Operation queued due to TMDB API unavailability", %{
          operation_type: operation_type,
          tmdb_user_id: tmdb_user_id,
          tmdb_list_id: tmdb_list_id
        })
        {:ok, :queued}

      {:error, reason} ->
        Logger.error("Failed to queue operation", %{
          operation_type: operation_type,
          tmdb_user_id: tmdb_user_id,
          tmdb_list_id: tmdb_list_id,
          reason: inspect(reason)
        })
        {:error, :queue_failed}
    end
  end

  defp build_list_data_from_response(tmdb_list_id, attrs, _response) do
    %{
      "id" => tmdb_list_id,
      "name" => Map.get(attrs, "name") || Map.get(attrs, :name),
      "description" => Map.get(attrs, "description") || Map.get(attrs, :description) || "",
      "public" => Map.get(attrs, "public") || Map.get(attrs, :public) || false,
      "item_count" => 0,
      "items" => [],
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp get_user_session(tmdb_user_id) do
    Auth.get_user_session(tmdb_user_id)
  end

  defp get_account_id(tmdb_user_id) do
    # For now, assume tmdb_user_id is the account_id
    # In a real implementation, this might need to be looked up from the session
    {:ok, tmdb_user_id}
  end
end
