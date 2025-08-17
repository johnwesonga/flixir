defmodule FlixirWeb.UserMovieListLive do
  @moduledoc """
  LiveView for viewing and managing a single TMDB movie list.

  This module handles the detailed view of an individual TMDB movie list, providing functionality
  for viewing movies in the list, adding and removing movies,
  displaying list statistics, and managing TMDB-specific features like sharing and visibility.
  It includes optimistic updates for better user experience, comprehensive error handling
  for TMDB API failures, and sync status indicators.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.UserMovieListComponents
  alias Flixir.Lists

  require Logger

  @impl true
  def mount(%{"tmdb_list_id" => tmdb_list_id_str}, _session, socket) do
    # Authentication state is handled by the on_mount hook
    if socket.assigns.authenticated? do
      case Integer.parse(tmdb_list_id_str) do
        {tmdb_list_id, ""} ->
          socket =
            socket
            |> assign(:tmdb_list_id, tmdb_list_id)
            |> assign(:list, nil)
            |> assign(:movies, [])
            |> assign(:loading, true)
            |> assign(:error, nil)
            |> assign(:stats, %{})
            |> assign(:show_add_movie_modal, false)
            |> assign(:show_remove_confirmation, false)
            |> assign(:show_share_modal, false)
            |> assign(:selected_movie, nil)
            |> assign(:page_title, "Movie List")
            |> assign(:current_section, :lists)
            # TMDB-specific state
            |> assign(:sync_status, :synced)
            |> assign(:last_sync_at, nil)
            |> assign(:optimistic_movies, [])
            |> assign(:queued_operations, [])
            |> assign(:tmdb_share_url, nil)
            |> assign(:show_privacy_toggle, false)
            |> load_list_data()

          {:ok, socket}

        _ ->
          socket =
            socket
            |> put_flash(:error, "Invalid list ID.")
            |> redirect(to: ~p"/my-lists")

          {:ok, socket}
      end
    else
      # Redirect to login if not authenticated
      socket =
        socket
        |> put_flash(:error, "Please log in to access your movie lists.")
        |> redirect(to: ~p"/auth/login")

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end





  @impl true
  def handle_event("show_share_modal", _params, socket) do
    list = socket.assigns.list
    tmdb_list_id = socket.assigns.tmdb_list_id

    if list && Map.get(list, "public", false) do
      # Generate TMDB share URL
      share_url = "https://www.themoviedb.org/list/#{tmdb_list_id}"

      socket =
        socket
        |> assign(:show_share_modal, true)
        |> assign(:tmdb_share_url, share_url)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Only public lists can be shared.")}
    end
  end

  @impl true
  def handle_event("cancel_share", _params, socket) do
    socket =
      socket
      |> assign(:show_share_modal, false)
      |> assign(:tmdb_share_url, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("copy_share_url", _params, socket) do
    # The actual copying is handled by JavaScript
    socket = put_flash(socket, :info, "Share URL copied to clipboard!")
    {:noreply, socket}
  end

  @impl true
  def handle_event("sync_with_tmdb", _params, socket) do
    tmdb_list_id = socket.assigns.tmdb_list_id
    current_user = socket.assigns.current_user

    socket = assign(socket, :sync_status, :syncing)

    # Force refresh from TMDB
    send(self(), {:force_sync_list, tmdb_list_id, current_user["id"]})

    socket = put_flash(socket, :info, "Syncing with TMDB...")
    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_failed_operations", _params, socket) do
    current_user = socket.assigns.current_user

    # Trigger retry of failed operations
    send(self(), {:retry_failed_operations, current_user["id"]})

    socket = put_flash(socket, :info, "Retrying failed operations...")
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_add_movie_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_add_movie_modal, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_add_movie", _params, socket) do
    socket =
      socket
      |> assign(:show_add_movie_modal, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_movie_by_id", %{"movie_id" => movie_id_str}, socket) do
    tmdb_list_id = socket.assigns.tmdb_list_id

    case Integer.parse(movie_id_str) do
      {movie_id, ""} ->
        # Optimistic update - add movie to UI immediately
        optimistic_movie = %{
          "id" => movie_id,
          "title" => "Loading...",
          "poster_path" => nil,
          "overview" => "Loading movie details...",
          "release_date" => nil,
          "vote_average" => 0,
          "added_at" => DateTime.utc_now(),
          "_loading" => true,
          "_optimistic" => true
        }

        socket =
          socket
          |> assign(:movies, [optimistic_movie | socket.assigns.movies])
          |> assign(:optimistic_movies, [movie_id | socket.assigns.optimistic_movies])
          |> assign(:show_add_movie_modal, false)
          |> assign(:sync_status, :syncing)

        # Add movie to TMDB list in background
        send(self(), {:add_movie_to_tmdb_list, tmdb_list_id, movie_id})

        {:noreply, socket}

      _ ->
        socket =
          socket
          |> put_flash(:error, "Invalid movie ID. Please enter a valid number.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_remove_confirmation", %{"movie-id" => movie_id_str}, socket) do
    case Integer.parse(movie_id_str) do
      {movie_id, ""} ->
        selected_movie = Enum.find(socket.assigns.movies, &(&1["id"] == movie_id))

        socket =
          socket
          |> assign(:show_remove_confirmation, true)
          |> assign(:selected_movie, selected_movie)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid movie ID.")}
    end
  end

  @impl true
  def handle_event("confirm_remove_movie", %{"movie-id" => movie_id_str}, socket) do
    tmdb_list_id = socket.assigns.tmdb_list_id

    case Integer.parse(movie_id_str) do
      {movie_id, ""} ->
        # Store the movie being removed for potential rollback
        removed_movie = Enum.find(socket.assigns.movies, &(&1["id"] == movie_id))

        # Optimistic update - remove movie from UI immediately
        updated_movies = Enum.reject(socket.assigns.movies, &(&1["id"] == movie_id))

        socket =
          socket
          |> assign(:movies, updated_movies)
          |> assign(:show_remove_confirmation, false)
          |> assign(:selected_movie, nil)
          |> assign(:sync_status, :syncing)

        # Remove movie from TMDB list in background
        send(self(), {:remove_movie_from_tmdb_list, tmdb_list_id, movie_id, removed_movie})

        {:noreply, socket}

      _ ->
        socket =
          socket
          |> assign(:show_remove_confirmation, false)
          |> assign(:selected_movie, nil)
          |> put_flash(:error, "Invalid movie ID.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_remove_movie", _params, socket) do
    socket =
      socket
      |> assign(:show_remove_confirmation, false)
      |> assign(:selected_movie, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    socket =
      socket
      |> assign(:error, nil)
      |> assign(:loading, true)
      |> load_list_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("back_to_lists", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/my-lists")}
  end

  # Handle background TMDB operations
  @impl true
  def handle_info({:add_movie_to_tmdb_list, tmdb_list_id, movie_id}, socket) do
    current_user = socket.assigns.current_user

    case Lists.add_movie_to_list(tmdb_list_id, movie_id, current_user["id"]) do
      {:ok, :queued} ->
        Logger.info("Movie addition queued for TMDB sync", %{
          tmdb_user_id: current_user["id"],
          tmdb_list_id: tmdb_list_id,
          movie_id: movie_id
        })

        # Keep optimistic update but mark as queued
        optimistic_movies = List.delete(socket.assigns.optimistic_movies, movie_id)

        socket =
          socket
          |> assign(:optimistic_movies, optimistic_movies)
          |> assign(:sync_status, :offline)
          |> load_queued_operations()
          |> put_flash(:info, "Movie added locally. Will sync when TMDB is available.")

        {:noreply, socket}

      {:ok, :added} ->
        Logger.info("Movie added to TMDB list", %{
          tmdb_user_id: current_user["id"],
          tmdb_list_id: tmdb_list_id,
          movie_id: movie_id
        })

        # Remove from optimistic list and reload movies to get actual movie data
        optimistic_movies = List.delete(socket.assigns.optimistic_movies, movie_id)

        socket =
          socket
          |> assign(:optimistic_movies, optimistic_movies)
          |> assign(:sync_status, :synced)
          |> assign(:last_sync_at, DateTime.utc_now())
          |> load_list_movies()
          |> load_list_stats()
          |> put_flash(:info, "Movie added to list successfully!")

        {:noreply, socket}

      {:error, :duplicate_movie} ->
        # Remove the optimistic movie and show error
        updated_movies =
          Enum.reject(
            socket.assigns.movies,
            &(&1["id"] == movie_id && Map.get(&1, "_optimistic"))
          )

        optimistic_movies = List.delete(socket.assigns.optimistic_movies, movie_id)

        socket =
          socket
          |> assign(:movies, updated_movies)
          |> assign(:optimistic_movies, optimistic_movies)
          |> assign(:sync_status, :synced)
          |> put_flash(:error, "This movie is already in your list.")

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to add movie to TMDB list", %{
          tmdb_user_id: current_user["id"],
          tmdb_list_id: tmdb_list_id,
          movie_id: movie_id,
          reason: inspect(reason)
        })

        # Remove the optimistic movie and show error
        updated_movies =
          Enum.reject(
            socket.assigns.movies,
            &(&1["id"] == movie_id && Map.get(&1, "_optimistic"))
          )

        optimistic_movies = List.delete(socket.assigns.optimistic_movies, movie_id)

        error_message =
          case reason do
            :unauthorized -> "You don't have permission to modify this list."
            :not_found -> "List or movie not found."
            _ -> "Failed to add movie to list. Please try again."
          end

        socket =
          socket
          |> assign(:movies, updated_movies)
          |> assign(:optimistic_movies, optimistic_movies)
          |> assign(:sync_status, :error)
          |> put_flash(:error, error_message)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remove_movie_from_tmdb_list, tmdb_list_id, movie_id, removed_movie}, socket) do
    current_user = socket.assigns.current_user

    case Lists.remove_movie_from_list(tmdb_list_id, movie_id, current_user["id"]) do
      {:ok, :removed} ->
        Logger.info("Movie removed from TMDB list", %{
          tmdb_user_id: current_user["id"],
          tmdb_list_id: tmdb_list_id,
          movie_id: movie_id
        })

        socket =
          socket
          |> assign(:sync_status, :synced)
          |> assign(:last_sync_at, DateTime.utc_now())
          |> load_list_stats()
          |> put_flash(:info, "Movie removed from list successfully!")

        {:noreply, socket}

      {:ok, :queued} ->
        Logger.info("Movie removal queued for TMDB sync", %{
          tmdb_user_id: current_user["id"],
          tmdb_list_id: tmdb_list_id,
          movie_id: movie_id
        })

        socket =
          socket
          |> assign(:sync_status, :offline)
          |> load_queued_operations()
          |> put_flash(:info, "Movie removed locally. Will sync when TMDB is available.")

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to remove movie from TMDB list", %{
          tmdb_user_id: current_user["id"],
          tmdb_list_id: tmdb_list_id,
          movie_id: movie_id,
          reason: inspect(reason)
        })

        # Restore the movie to the UI since removal failed
        restored_movies =
          if removed_movie do
            [removed_movie | socket.assigns.movies]
          else
            socket.assigns.movies
          end

        error_message =
          case reason do
            :unauthorized -> "You don't have permission to modify this list."
            :not_found -> "Movie not found in list."
            _ -> "Failed to remove movie from list. Please try again."
          end

        socket =
          socket
          |> assign(:movies, restored_movies)
          |> assign(:sync_status, :error)
          |> put_flash(:error, error_message)

        {:noreply, socket}
    end
  end



  @impl true
  def handle_info({:force_sync_list, tmdb_list_id, tmdb_user_id}, socket) do
    # Force refresh from TMDB by invalidating cache
    case Lists.get_list(tmdb_list_id, tmdb_user_id) do
      {:ok, fresh_list} ->
        socket =
          socket
          |> assign(:list, fresh_list)
          |> assign(:sync_status, :synced)
          |> assign(:last_sync_at, DateTime.utc_now())
          |> load_list_movies()
          |> load_list_stats()
          |> put_flash(:info, "List synced with TMDB successfully!")

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to sync list with TMDB", %{
          tmdb_list_id: tmdb_list_id,
          reason: inspect(reason)
        })

        socket =
          socket
          |> assign(:sync_status, :error)
          |> put_flash(:error, "Failed to sync with TMDB. Please try again.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:retry_failed_operations, _tmdb_user_id}, socket) do
    # This would trigger the queue processor to retry failed operations
    # For now, just reload the queue status
    socket =
      socket
      |> load_queued_operations()
      |> put_flash(:info, "Retrying failed operations...")

    {:noreply, socket}
  end

  # Private helper functions

  defp load_list_data(socket) do
    tmdb_list_id = socket.assigns.tmdb_list_id
    current_user = socket.assigns.current_user

    try do
      case Lists.get_list(tmdb_list_id, current_user["id"]) do
        {:ok, list} ->
          Logger.debug("Loaded TMDB list data", %{
            tmdb_user_id: current_user["id"],
            tmdb_list_id: tmdb_list_id,
            list_name: Map.get(list, "name")
          })

          socket
          |> assign(:list, list)
          |> assign(:page_title, Map.get(list, "name", "Movie List"))
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:sync_status, :synced)
          |> assign(:last_sync_at, DateTime.utc_now())
          |> load_list_movies()
          |> load_list_stats()
          |> load_queued_operations()

        {:error, :not_found} ->
          Logger.warning("TMDB list not found", %{
            tmdb_user_id: current_user["id"],
            tmdb_list_id: tmdb_list_id
          })

          socket
          |> assign(:loading, false)
          |> assign(:error, "List not found on TMDB.")
          |> redirect(to: ~p"/my-lists")

        {:error, :unauthorized} ->
          Logger.warning("Unauthorized TMDB list access", %{
            tmdb_user_id: current_user["id"],
            tmdb_list_id: tmdb_list_id
          })

          socket
          |> assign(:loading, false)
          |> put_flash(:error, "You don't have permission to access this list.")
          |> redirect(to: ~p"/my-lists")

        {:error, reason} ->
          Logger.error("Failed to load TMDB list", %{
            tmdb_user_id: current_user["id"],
            tmdb_list_id: tmdb_list_id,
            reason: inspect(reason)
          })

          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load list from TMDB. Please try again.")
          |> assign(:sync_status, :error)
      end
    rescue
      error ->
        Logger.error("Exception loading TMDB list data", %{
          tmdb_user_id: current_user["id"],
          tmdb_list_id: tmdb_list_id,
          error: inspect(error)
        })

        socket
        |> assign(:loading, false)
        |> assign(:error, "An unexpected error occurred. Please try again.")
        |> assign(:sync_status, :error)
    end
  end

  defp load_list_movies(socket) do
    tmdb_list_id = socket.assigns.tmdb_list_id
    current_user = socket.assigns.current_user

    if tmdb_list_id do
      case Lists.get_list_movies(tmdb_list_id, current_user["id"]) do
        {:ok, movies} ->
          Logger.debug("Loaded TMDB list movies", %{
            tmdb_user_id: current_user["id"],
            tmdb_list_id: tmdb_list_id,
            movie_count: length(movies)
          })

          # Filter out any optimistic movies that are now confirmed
          optimistic_movie_ids = socket.assigns.optimistic_movies

          confirmed_movies =
            Enum.reject(movies, fn movie ->
              movie_id = movie["id"]
              Enum.member?(optimistic_movie_ids, movie_id)
            end)

          # Keep optimistic movies that haven't been confirmed yet
          optimistic_movies =
            Enum.filter(socket.assigns.movies, fn movie ->
              Map.get(movie, "_optimistic", false)
            end)

          all_movies = optimistic_movies ++ confirmed_movies

          assign(socket, :movies, all_movies)

        {:error, reason} ->
          Logger.error("Failed to load TMDB list movies", %{
            tmdb_user_id: current_user["id"],
            tmdb_list_id: tmdb_list_id,
            reason: inspect(reason)
          })

          socket
          |> assign(:movies, [])
          |> put_flash(
            :error,
            "Failed to load movies from TMDB. Some movie details may be unavailable."
          )
      end
    else
      assign(socket, :movies, [])
    end
  end

  defp load_list_stats(socket) do
    tmdb_list_id = socket.assigns.tmdb_list_id
    current_user = socket.assigns.current_user

    if tmdb_list_id do
      case Lists.get_list_stats(tmdb_list_id, current_user["id"]) do
        {:ok, stats} ->
          Logger.debug("Loaded TMDB list stats", %{
            tmdb_list_id: tmdb_list_id,
            movie_count: stats.movie_count
          })

          assign(socket, :stats, stats)

        {:error, reason} ->
          Logger.error("Failed to load TMDB list stats", %{
            tmdb_list_id: tmdb_list_id,
            reason: inspect(reason)
          })

          assign(socket, :stats, %{})
      end
    else
      assign(socket, :stats, %{})
    end
  end

  defp load_queued_operations(socket) do
    current_user = socket.assigns.current_user

    if current_user do
      queue_stats = Lists.get_user_queue_stats(current_user["id"])
      assign(socket, :queued_operations, queue_stats)
    else
      assign(socket, :queued_operations, %{})
    end
  end
end
