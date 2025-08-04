defmodule FlixirWeb.UserMovieListsLive do
  @moduledoc """
  LiveView for displaying and managing all user movie lists.

  This module handles the overview of user-created movie lists, providing functionality
  for creating, editing, deleting, and clearing lists. It includes authentication checks,
  real-time updates, and comprehensive error handling with user feedback.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.AppLayout
  import FlixirWeb.UserMovieListComponents
  alias Flixir.Lists
  alias Flixir.Lists.UserMovieList

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Authentication state is handled by the on_mount hook
    if socket.assigns.authenticated? do
      socket =
        socket
        |> assign(:lists, [])
        |> assign(:loading, true)
        |> assign(:error, nil)
        |> assign(:show_form, nil)
        |> assign(:form_data, %{})
        |> assign(:selected_list, nil)
        |> assign(:show_delete_confirmation, false)
        |> assign(:show_clear_confirmation, false)
        |> assign(:lists_summary, %{})
        |> assign(:page_title, "My Movie Lists")
        |> assign(:current_section, :lists)
        |> load_user_lists()

      {:ok, socket}
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
  def handle_event("show_create_form", _params, socket) do
    changeset = UserMovieList.changeset(%UserMovieList{}, %{})

    socket =
      socket
      |> assign(:show_form, :create)
      |> assign(:form_data, to_form(changeset))

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_list", %{"list-id" => list_id}, socket) do
    case find_list_by_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        changeset = UserMovieList.update_changeset(list, %{})

        socket =
          socket
          |> assign(:show_form, :edit)
          |> assign(:selected_list, list)
          |> assign(:form_data, to_form(changeset))

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_list", %{"user_movie_list" => list_params}, socket) do
    current_user = socket.assigns.current_user

    case Lists.create_list(current_user["id"], list_params) do
      {:ok, new_list} ->
        Logger.info("User created new movie list", %{
          tmdb_user_id: current_user["id"],
          list_id: new_list.id,
          list_name: new_list.name
        })

        socket =
          socket
          |> assign(:show_form, nil)
          |> assign(:form_data, %{})
          |> put_flash(:info, "List \"#{new_list.name}\" created successfully!")
          |> load_user_lists()

        {:noreply, socket}

      {:error, changeset} ->
        Logger.warning("Failed to create movie list", %{
          tmdb_user_id: current_user["id"],
          errors: changeset.errors
        })

        socket =
          socket
          |> assign(:form_data, to_form(changeset))
          |> put_flash(:error, "Failed to create list. Please check the form for errors.")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_list", %{"user_movie_list" => list_params}, socket) do
    selected_list = socket.assigns.selected_list

    case Lists.update_list(selected_list, list_params) do
      {:ok, updated_list} ->
        Logger.info("User updated movie list", %{
          tmdb_user_id: socket.assigns.current_user["id"],
          list_id: updated_list.id,
          list_name: updated_list.name
        })

        socket =
          socket
          |> assign(:show_form, nil)
          |> assign(:selected_list, nil)
          |> assign(:form_data, %{})
          |> put_flash(:info, "List \"#{updated_list.name}\" updated successfully!")
          |> load_user_lists()

        {:noreply, socket}

      {:error, changeset} ->
        Logger.warning("Failed to update movie list", %{
          tmdb_user_id: socket.assigns.current_user["id"],
          list_id: selected_list.id,
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
  def handle_event("show_delete_confirmation", %{"list-id" => list_id}, socket) do
    case find_list_by_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        socket =
          socket
          |> assign(:selected_list, list)
          |> assign(:show_delete_confirmation, true)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"list-id" => list_id}, socket) do
    case find_list_by_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> assign(:show_delete_confirmation, false)
          |> assign(:selected_list, nil)
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        case Lists.delete_list(list) do
          {:ok, deleted_list} ->
            Logger.info("User deleted movie list", %{
              tmdb_user_id: socket.assigns.current_user["id"],
              list_id: deleted_list.id,
              list_name: deleted_list.name
            })

            socket =
              socket
              |> assign(:show_delete_confirmation, false)
              |> assign(:selected_list, nil)
              |> put_flash(:info, "List \"#{deleted_list.name}\" deleted successfully!")
              |> load_user_lists()

            {:noreply, socket}

          {:error, _changeset} ->
            Logger.error("Failed to delete movie list", %{
              tmdb_user_id: socket.assigns.current_user["id"],
              list_id: list.id
            })

            socket =
              socket
              |> assign(:show_delete_confirmation, false)
              |> assign(:selected_list, nil)
              |> put_flash(:error, "Failed to delete list. Please try again.")

            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    socket =
      socket
      |> assign(:show_delete_confirmation, false)
      |> assign(:selected_list, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_clear_confirmation", %{"list-id" => list_id}, socket) do
    case find_list_by_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        # Only show confirmation if list has movies
        if length(list.list_items || []) > 0 do
          socket =
            socket
            |> assign(:selected_list, list)
            |> assign(:show_clear_confirmation, true)

          {:noreply, socket}
        else
          socket =
            socket
            |> put_flash(:info, "List is already empty.")

          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("confirm_clear", %{"list-id" => list_id}, socket) do
    case find_list_by_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> assign(:show_clear_confirmation, false)
          |> assign(:selected_list, nil)
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        case Lists.clear_list(list) do
          {:ok, {count, nil}} ->
            Logger.info("User cleared movie list", %{
              tmdb_user_id: socket.assigns.current_user["id"],
              list_id: list.id,
              list_name: list.name,
              movies_removed: count
            })

            movie_word = if count == 1, do: "movie", else: "movies"

            socket =
              socket
              |> assign(:show_clear_confirmation, false)
              |> assign(:selected_list, nil)
              |> put_flash(:info, "Removed #{count} #{movie_word} from \"#{list.name}\"!")
              |> load_user_lists()

            {:noreply, socket}

          {:error, _reason} ->
            Logger.error("Failed to clear movie list", %{
              tmdb_user_id: socket.assigns.current_user["id"],
              list_id: list.id
            })

            socket =
              socket
              |> assign(:show_clear_confirmation, false)
              |> assign(:selected_list, nil)
              |> put_flash(:error, "Failed to clear list. Please try again.")

            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("cancel_clear", _params, socket) do
    socket =
      socket
      |> assign(:show_clear_confirmation, false)
      |> assign(:selected_list, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    socket =
      socket
      |> assign(:show_form, nil)
      |> assign(:selected_list, nil)
      |> assign(:form_data, %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("view_list", %{"list-id" => list_id}, socket) do
    # For now, just show a message since individual list view is task 7
    case find_list_by_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        socket =
          socket
          |> put_flash(:info, "Individual list view coming soon! List: \"#{list.name}\"")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("retry", _params, socket) do
    socket =
      socket
      |> assign(:error, nil)
      |> assign(:loading, true)
      |> load_user_lists()

    {:noreply, socket}
  end

  # Private helper functions

  defp load_user_lists(socket) do
    current_user = socket.assigns.current_user

    try do
      lists = Lists.get_user_lists(current_user["id"])
      summary = Lists.get_user_lists_summary(current_user["id"])

      Logger.debug("Loaded user lists", %{
        tmdb_user_id: current_user["id"],
        list_count: length(lists)
      })

      socket
      |> assign(:lists, lists)
      |> assign(:lists_summary, summary)
      |> assign(:loading, false)
      |> assign(:error, nil)
    rescue
      error ->
        Logger.error("Failed to load user lists", %{
          tmdb_user_id: current_user["id"],
          error: inspect(error)
        })

        socket
        |> assign(:loading, false)
        |> assign(:error, "Failed to load your movie lists. Please try again.")
    end
  end

  defp find_list_by_id(lists, list_id) do
    Enum.find(lists, fn list -> list.id == list_id end)
  end
end
