defmodule FlixirWeb.UserMovieListsLive do
  @moduledoc """
  LiveView for displaying and managing all user movie lists with TMDB integration.

  This module handles the overview of user-created movie lists using TMDB's native
  list management API. It provides functionality for creating, deleting,
  and clearing lists with optimistic updates, offline support through operation
  queuing, and comprehensive error handling with user feedback.

  Features:
  - TMDB API integration with local caching
  - Optimistic updates with rollback on failure
  - Operation queuing for offline scenarios
  - Session expiration handling and re-authentication
  - Real-time sync status indicators
  """

  use FlixirWeb, :live_view
  import FlixirWeb.AppLayout
  import FlixirWeb.UserMovieListComponents
  alias Flixir.Lists
  alias Flixir.Lists.Queue

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
        |> assign(:show_delete_confirmation, false)
        |> assign(:show_clear_confirmation, false)
        |> assign(:lists_summary, %{})
        |> assign(:page_title, "My Movie Lists")
        |> assign(:current_section, :lists)
        # TMDB integration state
        |> assign(:tmdb_session_id, nil)
        |> assign(:optimistic_updates, [])
        |> assign(:queued_operations, [])
        |> assign(:sync_status, :syncing)
        |> assign(:last_sync_at, nil)
        |> assign(:queue_stats, %{pending_operations: 0, failed_operations: 0})
        |> load_user_lists()
        |> load_queue_stats()

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
    form_data = to_form(%{"name" => "", "description" => "", "is_public" => false}, as: :list)

    socket =
      socket
      |> assign(:show_form, :create)
      |> assign(:form_data, form_data)

    {:noreply, socket}
  end



  @impl true
  def handle_event("create_list", %{"list" => list_params}, socket) do
    current_user = socket.assigns.current_user
    tmdb_user_id = current_user["id"]

    # Validate form data
    case validate_list_params(list_params) do
      {:ok, validated_params} ->
        # Create optimistic list entry
        optimistic_list = create_optimistic_list(validated_params, tmdb_user_id)

        socket =
          socket
          |> add_optimistic_update(:create_list, optimistic_list)
          |> assign(:show_form, nil)
          |> assign(:form_data, %{})
          |> assign(:sync_status, :syncing)

        # Attempt TMDB API call
        case Lists.create_list(tmdb_user_id, validated_params) do
          {:ok, :queued} ->
            Logger.info("List creation queued for later processing", %{
              tmdb_user_id: tmdb_user_id,
              list_name: validated_params["name"]
            })

            socket =
              socket
              |> put_flash(:info, "List \"#{validated_params["name"]}\" will be created when TMDB is available.")
              |> assign(:sync_status, :offline)
              |> load_queue_stats()

            {:noreply, socket}

          {:ok, new_list} ->
            Logger.info("User created new movie list via TMDB", %{
              tmdb_user_id: tmdb_user_id,
              tmdb_list_id: new_list["id"],
              list_name: new_list["name"]
            })

            socket =
              socket
              |> remove_optimistic_update(:create_list, optimistic_list["id"])
              |> put_flash(:info, "List \"#{new_list["name"]}\" created successfully!")
              |> assign(:sync_status, :synced)
              |> assign(:last_sync_at, DateTime.utc_now())
              |> load_user_lists()

            {:noreply, socket}

          {:error, :session_expired} ->
            socket =
              socket
              |> remove_optimistic_update(:create_list, optimistic_list["id"])
              |> handle_session_expired()

            {:noreply, socket}

          {:error, reason} ->
            Logger.warning("Failed to create movie list", %{
              tmdb_user_id: tmdb_user_id,
              reason: inspect(reason)
            })

            socket =
              socket
              |> remove_optimistic_update(:create_list, optimistic_list["id"])
              |> put_flash(:error, format_error_message(reason, "create list"))
              |> assign(:sync_status, :error)

            {:noreply, socket}
        end

      {:error, errors} ->
        form_data = to_form(list_params, as: :list, errors: errors)

        socket =
          socket
          |> assign(:form_data, form_data)
          |> put_flash(:error, "Please check the form for errors.")

        {:noreply, socket}
    end
  end



  @impl true
  def handle_event("show_delete_confirmation", %{"list-id" => list_id}, socket) do
    case find_list_by_tmdb_id(socket.assigns.lists, list_id) do
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
    case find_list_by_tmdb_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> assign(:show_delete_confirmation, false)
          |> assign(:selected_list, nil)
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        current_user = socket.assigns.current_user
        tmdb_user_id = current_user["id"]
        tmdb_list_id = list["id"]

        # Optimistic update: remove from UI immediately
        socket =
          socket
          |> add_optimistic_update(:delete_list, list)
          |> assign(:show_delete_confirmation, false)
          |> assign(:selected_list, nil)
          |> assign(:sync_status, :syncing)

        # Attempt TMDB API call
        case Lists.delete_list(tmdb_list_id, tmdb_user_id) do
          {:ok, :deleted} ->
            Logger.info("User deleted movie list via TMDB", %{
              tmdb_user_id: tmdb_user_id,
              tmdb_list_id: tmdb_list_id,
              list_name: list["name"]
            })

            socket =
              socket
              |> remove_optimistic_update(:delete_list, tmdb_list_id)
              |> put_flash(:info, "List \"#{list["name"]}\" deleted successfully!")
              |> assign(:sync_status, :synced)
              |> assign(:last_sync_at, DateTime.utc_now())
              |> load_user_lists()

            {:noreply, socket}

          {:ok, :queued} ->
            Logger.info("List deletion queued for later processing", %{
              tmdb_user_id: tmdb_user_id,
              tmdb_list_id: tmdb_list_id
            })

            socket =
              socket
              |> put_flash(:info, "List \"#{list["name"]}\" will be deleted when TMDB is available.")
              |> assign(:sync_status, :offline)
              |> load_queue_stats()

            {:noreply, socket}

          {:error, :session_expired} ->
            socket =
              socket
              |> remove_optimistic_update(:delete_list, tmdb_list_id)
              |> handle_session_expired()

            {:noreply, socket}

          {:error, reason} ->
            Logger.error("Failed to delete movie list", %{
              tmdb_user_id: tmdb_user_id,
              tmdb_list_id: tmdb_list_id,
              reason: inspect(reason)
            })

            socket =
              socket
              |> remove_optimistic_update(:delete_list, tmdb_list_id)
              |> put_flash(:error, format_error_message(reason, "delete list"))
              |> assign(:sync_status, :error)

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
    case find_list_by_tmdb_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        # Only show confirmation if list has movies
        item_count = Map.get(list, "item_count", 0)
        if item_count > 0 do
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
    case find_list_by_tmdb_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> assign(:show_clear_confirmation, false)
          |> assign(:selected_list, nil)
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        current_user = socket.assigns.current_user
        tmdb_user_id = current_user["id"]
        tmdb_list_id = list["id"]
        item_count = Map.get(list, "item_count", 0)

        # Optimistic update: clear the list immediately
        optimistic_list = Map.put(list, "item_count", 0)

        socket =
          socket
          |> add_optimistic_update(:clear_list, optimistic_list)
          |> assign(:show_clear_confirmation, false)
          |> assign(:selected_list, nil)
          |> assign(:sync_status, :syncing)

        # Attempt TMDB API call
        case Lists.clear_list(tmdb_list_id, tmdb_user_id) do
          {:ok, :cleared} ->
            Logger.info("User cleared movie list via TMDB", %{
              tmdb_user_id: tmdb_user_id,
              tmdb_list_id: tmdb_list_id,
              list_name: list["name"],
              movies_removed: item_count
            })

            movie_word = if item_count == 1, do: "movie", else: "movies"

            socket =
              socket
              |> remove_optimistic_update(:clear_list, tmdb_list_id)
              |> put_flash(:info, "Removed #{item_count} #{movie_word} from \"#{list["name"]}\"!")
              |> assign(:sync_status, :synced)
              |> assign(:last_sync_at, DateTime.utc_now())
              |> load_user_lists()

            {:noreply, socket}

          {:ok, :queued} ->
            Logger.info("List clear queued for later processing", %{
              tmdb_user_id: tmdb_user_id,
              tmdb_list_id: tmdb_list_id
            })

            socket =
              socket
              |> put_flash(:info, "List \"#{list["name"]}\" will be cleared when TMDB is available.")
              |> assign(:sync_status, :offline)
              |> load_queue_stats()

            {:noreply, socket}

          {:error, :session_expired} ->
            socket =
              socket
              |> remove_optimistic_update(:clear_list, tmdb_list_id)
              |> handle_session_expired()

            {:noreply, socket}

          {:error, reason} ->
            Logger.error("Failed to clear movie list", %{
              tmdb_user_id: tmdb_user_id,
              tmdb_list_id: tmdb_list_id,
              reason: inspect(reason)
            })

            socket =
              socket
              |> remove_optimistic_update(:clear_list, tmdb_list_id)
              |> put_flash(:error, format_error_message(reason, "clear list"))
              |> assign(:sync_status, :error)

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
      |> assign(:form_data, %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("view_list", %{"list-id" => list_id}, socket) do
    case find_list_by_tmdb_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      _list ->
        {:noreply, redirect(socket, to: ~p"/my-lists/#{list_id}")}
    end
  end

  @impl true
  def handle_event("retry", _params, socket) do
    socket =
      socket
      |> assign(:error, nil)
      |> assign(:loading, true)
      |> assign(:sync_status, :syncing)
      |> load_user_lists()

    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_failed_operations", _params, socket) do
    current_user = socket.assigns.current_user
    tmdb_user_id = current_user["id"]

    Logger.info("Retrying failed operations for user", %{tmdb_user_id: tmdb_user_id})

    # Trigger queue processing for this user's operations
    spawn(fn -> Queue.process_user_operations(tmdb_user_id) end)

    socket =
      socket
      |> put_flash(:info, "Retrying failed operations...")
      |> assign(:sync_status, :syncing)
      |> load_queue_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("sync_with_tmdb", _params, socket) do
    current_user = socket.assigns.current_user
    tmdb_user_id = current_user["id"]

    Logger.info("Manual sync with TMDB requested", %{tmdb_user_id: tmdb_user_id})

    socket =
      socket
      |> assign(:sync_status, :syncing)
      |> assign(:loading, true)
      |> load_user_lists()
      |> load_queue_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_privacy", %{"list-id" => list_id}, socket) do
    case find_list_by_tmdb_id(socket.assigns.lists, list_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "List not found.")

        {:noreply, socket}

      list ->
        current_user = socket.assigns.current_user
        tmdb_user_id = current_user["id"]
        tmdb_list_id = list["id"]
        current_privacy = Map.get(list, "public", false)
        new_privacy = !current_privacy

        # Optimistic update
        optimistic_list = Map.put(list, "public", new_privacy)

        socket =
          socket
          |> add_optimistic_update(:toggle_privacy, optimistic_list)
          |> assign(:sync_status, :syncing)

        # Attempt TMDB API call
        case Lists.update_list(tmdb_list_id, tmdb_user_id, %{"is_public" => new_privacy}) do
          {:ok, :queued} ->
            privacy_text = if new_privacy, do: "public", else: "private"

            socket =
              socket
              |> put_flash(:info, "List \"#{list["name"]}\" will be made #{privacy_text} when TMDB is available.")
              |> assign(:sync_status, :offline)
              |> load_queue_stats()

            {:noreply, socket}

          {:ok, updated_list} ->
            privacy_text = if new_privacy, do: "public", else: "private"

            socket =
              socket
              |> remove_optimistic_update(:toggle_privacy, tmdb_list_id)
              |> put_flash(:info, "List \"#{updated_list["name"]}\" is now #{privacy_text}.")
              |> assign(:sync_status, :synced)
              |> assign(:last_sync_at, DateTime.utc_now())
              |> load_user_lists()

            {:noreply, socket}

          {:error, :session_expired} ->
            socket =
              socket
              |> remove_optimistic_update(:toggle_privacy, tmdb_list_id)
              |> handle_session_expired()

            {:noreply, socket}

          {:error, reason} ->
            socket =
              socket
              |> remove_optimistic_update(:toggle_privacy, tmdb_list_id)
              |> put_flash(:error, format_error_message(reason, "update privacy"))
              |> assign(:sync_status, :error)

            {:noreply, socket}
        end
    end
  end

  # Private helper functions

  defp load_user_lists(socket) do
    current_user = socket.assigns.current_user
    tmdb_user_id = current_user["id"]

    case Lists.get_user_lists(tmdb_user_id) do
      {:ok, lists} ->
        case Lists.get_user_lists_summary(tmdb_user_id) do
          {:ok, summary} ->
            Logger.debug("Loaded user lists via TMDB integration", %{
              tmdb_user_id: tmdb_user_id,
              list_count: length(lists)
            })

            # Apply optimistic updates to the lists
            updated_lists = apply_optimistic_updates(lists, socket.assigns.optimistic_updates)

            socket
            |> assign(:lists, updated_lists)
            |> assign(:lists_summary, summary)
            |> assign(:loading, false)
            |> assign(:error, nil)
            |> assign(:sync_status, :synced)
            |> assign(:last_sync_at, DateTime.utc_now())

          {:error, reason} ->
            Logger.warning("Failed to load user lists summary", %{
              tmdb_user_id: tmdb_user_id,
              reason: inspect(reason)
            })

            socket
            |> assign(:lists, lists)
            |> assign(:lists_summary, %{})
            |> assign(:loading, false)
            |> assign(:error, nil)
            |> assign(:sync_status, :synced)
        end

      {:error, :unauthorized} ->
        Logger.warning("Unauthorized access to user lists", %{tmdb_user_id: tmdb_user_id})

        socket
        |> assign(:loading, false)
        |> assign(:error, "Session expired. Please log in again.")
        |> assign(:sync_status, :error)

      {:error, reason} ->
        Logger.error("Failed to load user lists", %{
          tmdb_user_id: tmdb_user_id,
          reason: inspect(reason)
        })

        socket
        |> assign(:loading, false)
        |> assign(:error, format_error_message(reason, "load lists"))
        |> assign(:sync_status, :error)
    end
  end

  defp load_queue_stats(socket) do
    current_user = socket.assigns.current_user
    tmdb_user_id = current_user["id"]

    queue_stats = Lists.get_user_queue_stats(tmdb_user_id)

    socket
    |> assign(:queue_stats, queue_stats)
  end

  defp find_list_by_tmdb_id(lists, tmdb_list_id) do
    tmdb_list_id = if is_binary(tmdb_list_id), do: String.to_integer(tmdb_list_id), else: tmdb_list_id
    Enum.find(lists, fn list -> list["id"] == tmdb_list_id end)
  end

  # Optimistic updates management

  defp add_optimistic_update(socket, operation_type, data) do
    optimistic_update = %{
      id: generate_optimistic_id(),
      type: operation_type,
      data: data,
      timestamp: DateTime.utc_now()
    }

    current_updates = socket.assigns.optimistic_updates
    updated_updates = [optimistic_update | current_updates]

    socket
    |> assign(:optimistic_updates, updated_updates)
  end

  defp remove_optimistic_update(socket, operation_type, data_id) do
    current_updates = socket.assigns.optimistic_updates

    updated_updates = Enum.reject(current_updates, fn update ->
      update.type == operation_type and get_data_id(update.data) == data_id
    end)

    socket
    |> assign(:optimistic_updates, updated_updates)
  end

  defp apply_optimistic_updates(lists, optimistic_updates) do
    Enum.reduce(optimistic_updates, lists, fn update, acc_lists ->
      case update.type do
        :create_list ->
          [update.data | acc_lists]



        :delete_list ->
          Enum.reject(acc_lists, fn list -> list["id"] == update.data["id"] end)

        :clear_list ->
          Enum.map(acc_lists, fn list ->
            if list["id"] == update.data["id"], do: update.data, else: list
          end)

        :toggle_privacy ->
          Enum.map(acc_lists, fn list ->
            if list["id"] == update.data["id"], do: update.data, else: list
          end)

        _ ->
          acc_lists
      end
    end)
  end

  defp generate_optimistic_id do
    "optimistic_#{System.unique_integer([:positive])}"
  end

  defp get_data_id(data) when is_map(data), do: data["id"]
  defp get_data_id(data), do: data

  # Validation and error handling

  defp validate_list_params(params) do
    name = String.trim(params["name"] || "")
    description = String.trim(params["description"] || "")
    is_public = params["is_public"] || false

    errors = []

    errors = if String.length(name) < 3 do
      [name: "must be at least 3 characters long"] ++ errors
    else
      errors
    end

    errors = if String.length(name) > 100 do
      [name: "must be less than 100 characters"] ++ errors
    else
      errors
    end

    errors = if String.length(description) > 500 do
      [description: "must be less than 500 characters"] ++ errors
    else
      errors
    end

    if errors == [] do
      {:ok, %{
        "name" => name,
        "description" => description,
        "is_public" => is_public
      }}
    else
      {:error, errors}
    end
  end

  defp create_optimistic_list(params, tmdb_user_id) do
    %{
      "id" => generate_optimistic_id(),
      "name" => params["name"],
      "description" => params["description"],
      "public" => params["is_public"],
      "item_count" => 0,
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "created_by" => tmdb_user_id
    }
  end

  defp handle_session_expired(socket) do
    Logger.warning("TMDB session expired, redirecting to login")

    socket
    |> put_flash(:error, "Your TMDB session has expired. Please log in again.")
    |> assign(:sync_status, :error)
    |> redirect(to: ~p"/auth/login")
  end

  defp format_error_message(reason, action) do
    case reason do
      :unauthorized ->
        "You are not authorized to #{action}."

      :not_found ->
        "The requested list was not found."

      :name_required ->
        "List name is required."

      :name_too_short ->
        "List name must be at least 3 characters long."

      :name_too_long ->
        "List name must be less than 100 characters."

      :description_too_long ->
        "Description must be less than 500 characters."

      :session_expired ->
        "Your session has expired. Please log in again."

      :api_unavailable ->
        "TMDB service is temporarily unavailable. Your changes have been queued."

      :network_error ->
        "Network error occurred. Please check your connection and try again."

      :quota_exceeded ->
        "TMDB API quota exceeded. Please try again later."

      _ ->
        "Failed to #{action}. Please try again."
    end
  end
end
