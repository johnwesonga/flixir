defmodule FlixirWeb.UserMovieListLive do
  @moduledoc """
  LiveView for viewing and managing a single user movie list.

  This module handles the detailed view of an individual movie list, providing functionality
  for viewing movies in the list, adding and removing movies, editing list details,
  and displaying list statistics. It includes optimistic updates for better user experience
  and comprehensive error handling.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.UserMovieListComponents
  alias Flixir.Lists
  alias Flixir.Lists.UserMovieList

  require Logger

  @impl true
  def mount(%{"id" => list_id}, _session, socket) do
    # Authentication state is handled by the on_mount hook
    if socket.assigns.authenticated? do
      # Validate list_id format (should be a UUID)
      case validate_uuid(list_id) do
        :ok ->
          socket =
            socket
            |> assign(:list_id, list_id)
            |> assign(:list, nil)
            |> assign(:movies, [])
            |> assign(:loading, true)
            |> assign(:error, nil)
            |> assign(:editing, false)
            |> assign(:form_data, %{})
            |> assign(:stats, %{})
            |> assign(:show_add_movie_modal, false)
            |> assign(:show_remove_confirmation, false)
            |> assign(:selected_movie, nil)
            |> assign(:page_title, "Movie List")
            |> assign(:current_section, :lists)
            |> load_list_data()

          {:ok, socket}

        :error ->
          Logger.warning("Invalid list ID format", %{
            list_id: list_id,
            tmdb_user_id: socket.assigns.current_user && socket.assigns.current_user["id"]
          })

          socket =
            socket
            |> put_flash(:error, "Invalid list ID format.")
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
    case socket.assigns.live_action do
      :edit ->
        list = socket.assigns.list

        if list do
          changeset = UserMovieList.update_changeset(list, %{})

          socket =
            socket
            |> assign(:editing, true)
            |> assign(:form_data, to_form(changeset))

          {:noreply, socket}
        else
          {:noreply, socket}
        end

      :show ->
        socket =
          socket
          |> assign(:editing, false)
          |> assign(:form_data, %{})

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_list", _params, socket) do
    list = socket.assigns.list

    if list do
      changeset = UserMovieList.update_changeset(list, %{})

      socket =
        socket
        |> assign(:editing, true)
        |> assign(:form_data, to_form(changeset))

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "List not found.")}
    end
  end

  @impl true
  def handle_event("update_list", %{"user_movie_list" => list_params}, socket) do
    list = socket.assigns.list
    current_user = socket.assigns.current_user

    case Lists.update_list(list, list_params) do
      {:ok, updated_list} ->
        Logger.info("User updated movie list", %{
          tmdb_user_id: current_user["id"],
          list_id: updated_list.id,
          list_name: updated_list.name
        })

        socket =
          socket
          |> assign(:editing, false)
          |> assign(:form_data, %{})
          |> assign(:list, updated_list)
          |> assign(:page_title, updated_list.name)
          |> put_flash(:info, "List \"#{updated_list.name}\" updated successfully!")
          |> load_list_stats()

        {:noreply, socket}

      {:error, changeset} ->
        Logger.warning("Failed to update movie list", %{
          tmdb_user_id: current_user["id"],
          list_id: list.id,
          errors: changeset.errors
        })

        socket =
          socket
          |> assign(:form_data, to_form(changeset))
          |> put_flash(:error, "Failed to update list. Please check the form for errors.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing, false)
      |> assign(:form_data, %{})

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
    list = socket.assigns.list

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
          "list_id" => list.id,
          "_loading" => true
        }

        socket =
          socket
          |> assign(:movies, [optimistic_movie | socket.assigns.movies])
          |> assign(:show_add_movie_modal, false)

        # Add movie to list in background
        send(self(), {:add_movie_to_list, movie_id})

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
    case Integer.parse(movie_id_str) do
      {movie_id, ""} ->
        # Optimistic update - remove movie from UI immediately
        updated_movies = Enum.reject(socket.assigns.movies, &(&1["id"] == movie_id))

        socket =
          socket
          |> assign(:movies, updated_movies)
          |> assign(:show_remove_confirmation, false)
          |> assign(:selected_movie, nil)

        # Remove movie from list in background
        send(self(), {:remove_movie_from_list, movie_id})

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

  # Handle background movie operations
  @impl true
  def handle_info({:add_movie_to_list, movie_id}, socket) do
    list = socket.assigns.list
    current_user = socket.assigns.current_user

    case Lists.add_movie_to_list(list.id, movie_id, current_user["id"]) do
      {:ok, _list_item} ->
        Logger.info("Movie added to list", %{
          tmdb_user_id: current_user["id"],
          list_id: list.id,
          movie_id: movie_id
        })

        # Reload movies to get actual movie data
        socket =
          socket
          |> load_list_movies()
          |> load_list_stats()
          |> put_flash(:info, "Movie added to list successfully!")

        {:noreply, socket}

      {:error, :duplicate_movie} ->
        # Remove the optimistic movie and show error
        updated_movies = Enum.reject(socket.assigns.movies, &(&1["id"] == movie_id && Map.get(&1, "_loading")))

        socket =
          socket
          |> assign(:movies, updated_movies)
          |> put_flash(:error, "This movie is already in your list.")

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to add movie to list", %{
          tmdb_user_id: current_user["id"],
          list_id: list.id,
          movie_id: movie_id,
          reason: inspect(reason)
        })

        # Remove the optimistic movie and show error
        updated_movies = Enum.reject(socket.assigns.movies, &(&1["id"] == movie_id && Map.get(&1, "_loading")))

        socket =
          socket
          |> assign(:movies, updated_movies)
          |> put_flash(:error, "Failed to add movie to list. Please try again.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remove_movie_from_list, movie_id}, socket) do
    list = socket.assigns.list
    current_user = socket.assigns.current_user

    case Lists.remove_movie_from_list(list.id, movie_id, current_user["id"]) do
      {:ok, _list_item} ->
        Logger.info("Movie removed from list", %{
          tmdb_user_id: current_user["id"],
          list_id: list.id,
          movie_id: movie_id
        })

        socket =
          socket
          |> load_list_stats()
          |> put_flash(:info, "Movie removed from list successfully!")

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to remove movie from list", %{
          tmdb_user_id: current_user["id"],
          list_id: list.id,
          movie_id: movie_id,
          reason: inspect(reason)
        })

        # Restore the movie to the UI since removal failed
        socket =
          socket
          |> load_list_movies()
          |> put_flash(:error, "Failed to remove movie from list. Please try again.")

        {:noreply, socket}
    end
  end

  # Private helper functions

  defp validate_uuid(uuid_string) do
    case Ecto.UUID.cast(uuid_string) do
      {:ok, _} -> :ok
      :error -> :error
    end
  end

  defp load_list_data(socket) do
    list_id = socket.assigns.list_id
    current_user = socket.assigns.current_user

    try do
      case Lists.get_list(list_id, current_user["id"]) do
        {:ok, list} ->
          Logger.debug("Loaded list data", %{
            tmdb_user_id: current_user["id"],
            list_id: list_id,
            list_name: list.name
          })

          socket
          |> assign(:list, list)
          |> assign(:page_title, list.name)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> load_list_movies()
          |> load_list_stats()

        {:error, :not_found} ->
          Logger.warning("List not found", %{
            tmdb_user_id: current_user["id"],
            list_id: list_id
          })

          socket
          |> assign(:loading, false)
          |> assign(:error, "List not found.")
          |> redirect(to: ~p"/my-lists")

        {:error, :unauthorized} ->
          Logger.warning("Unauthorized list access", %{
            tmdb_user_id: current_user["id"],
            list_id: list_id
          })

          socket
          |> assign(:loading, false)
          |> put_flash(:error, "You don't have permission to access this list.")
          |> redirect(to: ~p"/my-lists")

        {:error, reason} ->
          Logger.error("Failed to load list", %{
            tmdb_user_id: current_user["id"],
            list_id: list_id,
            reason: inspect(reason)
          })

          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load list. Please try again.")
      end
    rescue
      error ->
        Logger.error("Exception loading list data", %{
          tmdb_user_id: current_user["id"],
          list_id: list_id,
          error: inspect(error)
        })

        socket
        |> assign(:loading, false)
        |> assign(:error, "An unexpected error occurred. Please try again.")
    end
  end

  defp load_list_movies(socket) do
    list = socket.assigns.list
    current_user = socket.assigns.current_user

    if list do
      case Lists.get_list_movies(list.id, current_user["id"]) do
        {:ok, movies} ->
          Logger.debug("Loaded list movies", %{
            tmdb_user_id: current_user["id"],
            list_id: list.id,
            movie_count: length(movies)
          })

          assign(socket, :movies, movies)

        {:error, reason} ->
          Logger.error("Failed to load list movies", %{
            tmdb_user_id: current_user["id"],
            list_id: list.id,
            reason: inspect(reason)
          })

          socket
          |> assign(:movies, [])
          |> put_flash(:error, "Failed to load movies. Some movie details may be unavailable.")
      end
    else
      assign(socket, :movies, [])
    end
  end

  defp load_list_stats(socket) do
    list = socket.assigns.list

    if list do
      stats = Lists.get_list_stats(list.id)

      Logger.debug("Loaded list stats", %{
        list_id: list.id,
        movie_count: stats.movie_count
      })

      assign(socket, :stats, stats)
    else
      assign(socket, :stats, %{})
    end
  end
end
