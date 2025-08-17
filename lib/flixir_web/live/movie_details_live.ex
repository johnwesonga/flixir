defmodule FlixirWeb.MovieDetailsLive do
  @moduledoc """
  LiveView for displaying movie and TV show details with reviews.

  This module handles the display of media details along with user reviews,
  including filtering, sorting, and pagination functionality.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.ReviewComponents
  import FlixirWeb.ReviewFilters
  import FlixirWeb.UserMovieListComponents
  alias Flixir.{Media, Reviews, Lists}
  import FlixirWeb.AppLayout
  require Logger

  @default_list_type :popular

  @impl true
  def mount(%{"type" => media_type, "id" => media_id} = params, _session, socket) do
    media_id = String.to_integer(media_id)

    # Authentication state is now handled by the on_mount hook
    # Capture search context for back navigation
    search_context = extract_search_context(params)

    socket =
      socket
      |> assign(:media_type, media_type)
      |> assign(:media_id, media_id)
      |> assign(:search_context, search_context)
      |> assign(:media_details, nil)
      |> assign(:reviews, [])
      |> assign(:rating_stats, nil)
      |> assign(:loading_reviews, false)
      |> assign(:reviews_error, nil)
      |> assign(:reviews_state, :loading)
      |> assign(:rating_stats_state, :loading)
      |> assign(:rating_stats_error, nil)
      |> assign(:expanded_reviews, MapSet.new())
      |> assign(:revealed_spoilers, MapSet.new())
      |> assign(:review_filters, default_filters())
      |> assign(:filtered_reviews, [])
      |> assign(:pagination, nil)
      |> assign(:page_title, "Loading...")
      |> assign(:current_list, @default_list_type)
      # TMDB Lists integration
      |> assign(:user_lists, [])
      |> assign(:movie_list_membership, %{})
      |> assign(:loading_lists, false)
      |> assign(:lists_error, nil)
      |> assign(:show_add_to_list, false)
      |> assign(:optimistic_list_updates, %{})
      |> assign(:tmdb_user_id, nil)

    # Load media details, reviews, and user lists if authenticated
    socket =
      socket
      |> load_media_details()
      |> load_reviews()
      |> maybe_load_user_lists()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_filters", params, socket) do
    action = Map.get(params, "action")

    socket =
      case action do
        # Handle button-based actions (clear buttons, toggle sort order)
        "toggle_sort_order" ->
          current_order = Map.get(socket.assigns.review_filters, :sort_order, :desc)
          new_order = if current_order == :desc, do: :asc, else: :desc
          update_filter(socket, :sort_order, new_order)

        "clear_all" ->
          socket
          |> assign(:review_filters, default_filters())
          |> apply_filters()

        "clear_sort" ->
          socket
          |> update_filter(:sort_by, :date)
          |> update_filter(:sort_order, :desc)

        "clear_rating" ->
          update_filter(socket, :filter_by_rating, nil)

        "clear_author" ->
          update_filter(socket, :author_filter, nil)

        "clear_content" ->
          update_filter(socket, :content_filter, nil)

        # Handle form-based changes (when action is nil, it's a form change event)
        _ ->
          # Process all form fields at once
          socket =
            socket
            |> maybe_update_sort_by(Map.get(params, "sort_by"))
            |> maybe_update_rating_filter(Map.get(params, "filter_by_rating"))
            |> maybe_update_author_filter(Map.get(params, "author_filter"))
            |> maybe_update_content_filter(Map.get(params, "content_filter"))

          apply_filters(socket)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("expand_review", %{"review_id" => review_id}, socket) do
    expanded_reviews = MapSet.put(socket.assigns.expanded_reviews, review_id)
    socket = assign(socket, :expanded_reviews, expanded_reviews)
    {:noreply, socket}
  end

  @impl true
  def handle_event("collapse_review", %{"review_id" => review_id}, socket) do
    expanded_reviews = MapSet.delete(socket.assigns.expanded_reviews, review_id)
    socket = assign(socket, :expanded_reviews, expanded_reviews)
    {:noreply, socket}
  end

  @impl true
  def handle_event("reveal_spoilers", %{"review_id" => review_id}, socket) do
    revealed_spoilers = MapSet.put(socket.assigns.revealed_spoilers, review_id)
    socket = assign(socket, :revealed_spoilers, revealed_spoilers)
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_reviews", _params, socket) do
    current_page = get_in(socket.assigns, [:pagination, :page]) || 1
    next_page = current_page + 1

    socket = load_reviews(socket, page: next_page, append: true)
    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_reviews", _params, socket) do
    socket = load_reviews(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_rating_stats", _params, socket) do
    socket =
      socket
      |> assign(:rating_stats_state, :loading)
      |> load_rating_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear-filters", _params, socket) do
    socket =
      socket
      |> assign(:review_filters, default_filters())
      |> apply_filters()

    {:noreply, socket}
  end

  # TMDB Lists Integration Events

  @impl true
  def handle_event("show_add_to_list", _params, socket) do
    socket = assign(socket, :show_add_to_list, true)
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_add_to_list", _params, socket) do
    socket = assign(socket, :show_add_to_list, false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_movie_to_list", %{"list-id" => list_id, "movie-id" => movie_id}, socket) do
    tmdb_list_id = String.to_integer(list_id)
    tmdb_movie_id = String.to_integer(movie_id)
    tmdb_user_id = socket.assigns.tmdb_user_id

    if tmdb_user_id do
      # Optimistic update
      socket = add_optimistic_list_update(socket, tmdb_list_id, tmdb_movie_id, :adding)

      # Perform the actual API call
      case Lists.add_movie_to_list(tmdb_list_id, tmdb_movie_id, tmdb_user_id) do
        {:ok, :added} ->
          socket =
            socket
            |> remove_optimistic_list_update(tmdb_list_id, tmdb_movie_id)
            |> update_movie_list_membership(tmdb_list_id, tmdb_movie_id, true)
            |> assign(:show_add_to_list, false)
            |> put_flash(:info, "Movie added to list successfully!")

          {:noreply, socket}

        {:ok, :queued} ->
          socket =
            socket
            |> remove_optimistic_list_update(tmdb_list_id, tmdb_movie_id)
            |> put_flash(:info, "Movie will be added to list when TMDB is available")
            |> assign(:show_add_to_list, false)

          {:noreply, socket}

        {:error, :duplicate_movie} ->
          socket =
            socket
            |> remove_optimistic_list_update(tmdb_list_id, tmdb_movie_id)
            |> put_flash(:error, "Movie is already in this list")

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> remove_optimistic_list_update(tmdb_list_id, tmdb_movie_id)
            |> put_flash(:error, format_list_error(reason))

          {:noreply, socket}
      end
    else
      socket = put_flash(socket, :error, "Please log in to add movies to lists")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "remove_movie_from_list",
        %{"list-id" => list_id, "movie-id" => movie_id},
        socket
      ) do
    tmdb_list_id = String.to_integer(list_id)
    tmdb_movie_id = String.to_integer(movie_id)
    tmdb_user_id = socket.assigns.tmdb_user_id

    if tmdb_user_id do
      # Optimistic update
      socket = add_optimistic_list_update(socket, tmdb_list_id, tmdb_movie_id, :removing)

      # Perform the actual API call
      case Lists.remove_movie_from_list(tmdb_list_id, tmdb_movie_id, tmdb_user_id) do
        {:ok, :removed} ->
          socket =
            socket
            |> remove_optimistic_list_update(tmdb_list_id, tmdb_movie_id)
            |> update_movie_list_membership(tmdb_list_id, tmdb_movie_id, false)
            |> put_flash(:info, "Movie removed from list successfully!")

          {:noreply, socket}

        {:ok, :queued} ->
          socket =
            socket
            |> remove_optimistic_list_update(tmdb_list_id, tmdb_movie_id)
            |> put_flash(:info, "Movie will be removed from list when TMDB is available")

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> remove_optimistic_list_update(tmdb_list_id, tmdb_movie_id)
            |> put_flash(:error, format_list_error(reason))

          {:noreply, socket}
      end
    else
      socket = put_flash(socket, :error, "Please log in to manage lists")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("retry_load_lists", _params, socket) do
    socket = load_user_lists(socket)
    {:noreply, socket}
  end

  # Private functions

  defp default_filters do
    %{
      sort_by: :date,
      sort_order: :desc,
      filter_by_rating: nil,
      author_filter: nil,
      content_filter: nil
    }
  end

  defp update_filter(socket, key, value) do
    filters = Map.put(socket.assigns.review_filters, key, value)

    socket
    |> assign(:review_filters, filters)
    |> apply_filters()
  end

  defp apply_filters(socket) do
    filters = socket.assigns.review_filters
    reviews = socket.assigns.reviews

    # Apply filters and sorting
    filtered_reviews = Reviews.filter_reviews(reviews, filters)
    sorted_reviews = Reviews.sort_reviews(filtered_reviews, filters.sort_by, filters.sort_order)

    # Apply pagination
    per_page = 10
    page = 1
    paginated_result = Reviews.paginate_reviews(sorted_reviews, page, per_page)

    socket
    |> assign(:filtered_reviews, paginated_result.reviews)
    |> assign(:pagination, paginated_result.pagination)
  end

  defp parse_rating_filter(""), do: nil
  defp parse_rating_filter("positive"), do: :positive
  defp parse_rating_filter("negative"), do: :negative
  defp parse_rating_filter("high"), do: {8, 10}
  defp parse_rating_filter("medium"), do: {5, 7}
  defp parse_rating_filter("low"), do: {1, 4}
  defp parse_rating_filter(_), do: nil

  # Helper functions for updating individual filter fields
  defp maybe_update_sort_by(socket, nil), do: socket
  defp maybe_update_sort_by(socket, ""), do: socket

  defp maybe_update_sort_by(socket, sort_by) when is_binary(sort_by) do
    sort_by_atom = String.to_atom(sort_by)

    if sort_by_atom in [:date, :rating, :author] do
      update_filter(socket, :sort_by, sort_by_atom)
    else
      socket
    end
  end

  defp maybe_update_rating_filter(socket, nil), do: socket
  defp maybe_update_rating_filter(socket, ""), do: update_filter(socket, :filter_by_rating, nil)

  defp maybe_update_rating_filter(socket, rating_filter) when is_binary(rating_filter) do
    parsed_filter = parse_rating_filter(rating_filter)
    update_filter(socket, :filter_by_rating, parsed_filter)
  end

  defp maybe_update_author_filter(socket, nil), do: socket
  defp maybe_update_author_filter(socket, ""), do: update_filter(socket, :author_filter, nil)

  defp maybe_update_author_filter(socket, author_filter) when is_binary(author_filter) do
    trimmed_filter = String.trim(author_filter)
    filter_value = if trimmed_filter == "", do: nil, else: trimmed_filter
    update_filter(socket, :author_filter, filter_value)
  end

  defp maybe_update_content_filter(socket, nil), do: socket
  defp maybe_update_content_filter(socket, ""), do: update_filter(socket, :content_filter, nil)

  defp maybe_update_content_filter(socket, content_filter) when is_binary(content_filter) do
    trimmed_filter = String.trim(content_filter)
    filter_value = if trimmed_filter == "", do: nil, else: trimmed_filter
    update_filter(socket, :content_filter, filter_value)
  end

  defp load_media_details(socket) do
    media_type = socket.assigns.media_type
    media_id = socket.assigns.media_id

    # Convert string media_type to atom and fix parameter order
    media_type_atom =
      case media_type do
        "movie" -> :movie
        "tv" -> :tv
        # fallback
        _ -> :movie
      end

    case Media.get_content_details(media_id, media_type_atom) do
      {:ok, details} ->
        title = get_media_title(details, media_type)

        socket
        |> assign(:media_details, details)
        |> assign(:page_title, title)

      {:error, reason} ->
        Logger.error("Failed to load media details: #{inspect(reason)}")

        socket
        |> assign(:media_details, nil)
        |> assign(:page_title, "Media Not Found")
    end
  end

  defp load_reviews(socket, opts \\ []) do
    media_type = socket.assigns.media_type
    media_id = socket.assigns.media_id
    page = Keyword.get(opts, :page, 1)
    append = Keyword.get(opts, :append, false)

    socket = assign(socket, :loading_reviews, true)

    case Reviews.get_reviews(media_type, media_id, page: page) do
      {:ok, %{reviews: new_reviews, pagination: pagination}} ->
        existing_reviews = if append, do: socket.assigns.reviews, else: []
        all_reviews = existing_reviews ++ new_reviews

        socket
        |> assign(:reviews, all_reviews)
        |> assign(:pagination, pagination)
        |> assign(:loading_reviews, false)
        |> assign(:reviews_error, nil)
        |> assign(:reviews_state, :success)
        |> load_rating_stats()
        |> apply_filters()

      {:error, error_type} ->
        Logger.error("Failed to load reviews: #{inspect(error_type)}")

        error_info = %{
          error_type: error_type,
          retry_event: "retry_reviews"
        }

        socket
        |> assign(:loading_reviews, false)
        |> assign(:reviews_error, error_info)
        |> assign(:reviews_state, :error)
    end
  end

  defp load_rating_stats(socket) do
    media_type = socket.assigns.media_type
    media_id = socket.assigns.media_id

    case Reviews.get_rating_stats(media_type, media_id) do
      {:ok, stats} ->
        socket
        |> assign(:rating_stats, stats)
        |> assign(:rating_stats_state, :success)
        |> assign(:rating_stats_error, nil)

      {:error, error_type} ->
        Logger.warning("Failed to load rating stats: #{inspect(error_type)}")

        error_info = %{
          error_type: error_type,
          retry_event: "retry_rating_stats"
        }

        socket
        |> assign(:rating_stats_state, :error)
        |> assign(:rating_stats_error, error_info)
    end
  end

  defp get_media_title(details, "movie"), do: Map.get(details, "title", "Unknown Movie")
  defp get_media_title(details, "tv"), do: Map.get(details, "name", "Unknown TV Show")
  defp get_media_title(_, _), do: "Unknown Media"

  defp format_error_message(:invalid_media_type), do: "Invalid media type"
  defp format_error_message(:invalid_media_id), do: "Invalid media ID"
  defp format_error_message(:timeout), do: "Request timed out. Please try again."
  defp format_error_message(:rate_limited), do: "Too many requests. Please wait a moment."
  defp format_error_message(:unauthorized), do: "Unable to access reviews at this time."
  defp format_error_message(:not_found), do: "No reviews found for this content."

  defp format_error_message({:transport_error, _}),
    do: "Network error. Please check your connection."

  defp format_error_message({:unexpected_status, status}),
    do: "Service error (#{status}). Please try again later."

  defp format_error_message(%{__exception__: true}),
    do: "An unexpected error occurred. Please try again."

  defp format_error_message(%{error_type: error_type}), do: format_error_message(error_type)

  defp format_error_message(:network_error),
    do: "Network error occurred. Please check your connection and try again."

  defp format_error_message(_), do: "An error occurred while loading reviews."

  # Template helper functions

  defp get_release_date(details, "movie"), do: Map.get(details, "release_date")
  defp get_release_date(details, "tv"), do: Map.get(details, "first_air_date")
  defp get_release_date(_, _), do: nil

  defp format_release_date(nil), do: ""

  defp format_release_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Calendar.strftime(date, "%B %d, %Y")
      {:error, _} -> date_string
    end
  end

  defp format_release_date(_), do: ""

  defp extract_search_context(params) do
    %{
      query: Map.get(params, "q", ""),
      media_type: Map.get(params, "type", "all"),
      sort_by: Map.get(params, "sort", "relevance"),
      page: Map.get(params, "page", "1")
    }
  end

  # TMDB Lists Integration Helper Functions

  defp maybe_load_user_lists(socket) do
    if socket.assigns.authenticated? && socket.assigns.current_user do
      tmdb_user_id = get_tmdb_user_id(socket.assigns.current_user)

      socket
      |> assign(:tmdb_user_id, tmdb_user_id)
      |> load_user_lists()
    else
      socket
    end
  end

  defp load_user_lists(socket) do
    tmdb_user_id = socket.assigns.tmdb_user_id

    if tmdb_user_id do
      socket = assign(socket, :loading_lists, true)

      case Lists.get_user_lists(tmdb_user_id) do
        {:ok, lists} ->
          socket =
            socket
            |> assign(:user_lists, lists)
            |> assign(:loading_lists, false)
            |> assign(:lists_error, nil)
            |> load_movie_list_membership()

          socket

        {:error, reason} ->
          Logger.error("Failed to load user lists for movie details", %{
            tmdb_user_id: tmdb_user_id,
            reason: inspect(reason)
          })

          socket
          |> assign(:loading_lists, false)
          |> assign(:lists_error, reason)
      end
    else
      socket
    end
  end

  defp load_movie_list_membership(socket) do
    media_id = socket.assigns.media_id
    media_type = socket.assigns.media_type
    tmdb_user_id = socket.assigns.tmdb_user_id
    user_lists = socket.assigns.user_lists

    # Only check membership for movies (not TV shows for now)
    if media_type == "movie" && tmdb_user_id && !Enum.empty?(user_lists) do
      membership_map =
        user_lists
        |> Enum.reduce(%{}, fn list, acc ->
          list_id = list["id"]

          case Lists.movie_in_list?(list_id, media_id, tmdb_user_id) do
            {:ok, is_member} ->
              Map.put(acc, list_id, is_member)

            {:error, _reason} ->
              # If we can't check membership, assume false
              Map.put(acc, list_id, false)
          end
        end)

      assign(socket, :movie_list_membership, membership_map)
    else
      socket
    end
  end

  defp get_tmdb_user_id(current_user) do
    # Extract TMDB user ID from current user session
    # This assumes the current_user contains TMDB account information
    Map.get(current_user, :tmdb_user_id) || Map.get(current_user, "tmdb_user_id")
  end

  defp add_optimistic_list_update(socket, list_id, movie_id, action) do
    key = {list_id, movie_id}
    optimistic_updates = Map.put(socket.assigns.optimistic_list_updates, key, action)

    # Also update the membership map optimistically
    membership = socket.assigns.movie_list_membership

    updated_membership =
      case action do
        :adding -> Map.put(membership, list_id, true)
        :removing -> Map.put(membership, list_id, false)
      end

    socket
    |> assign(:optimistic_list_updates, optimistic_updates)
    |> assign(:movie_list_membership, updated_membership)
  end

  defp remove_optimistic_list_update(socket, list_id, movie_id) do
    key = {list_id, movie_id}
    optimistic_updates = Map.delete(socket.assigns.optimistic_list_updates, key)
    assign(socket, :optimistic_list_updates, optimistic_updates)
  end

  defp update_movie_list_membership(socket, list_id, _movie_id, is_member) do
    membership = Map.put(socket.assigns.movie_list_membership, list_id, is_member)
    assign(socket, :movie_list_membership, membership)
  end

  defp format_list_error(:unauthorized), do: "You don't have permission to modify this list"
  defp format_list_error(:not_found), do: "List not found"
  defp format_list_error(:duplicate_movie), do: "Movie is already in this list"
  defp format_list_error(:api_unavailable), do: "TMDB service is temporarily unavailable"
  defp format_list_error(:network_error), do: "Network error occurred. Please try again."
  defp format_list_error(_), do: "An error occurred while updating the list"

  defp build_search_url(search_context) do
    # Build the search URL with preserved context
    base_params = []

    # Add query parameter if present
    params =
      if search_context.query != "" do
        [{"q", search_context.query} | base_params]
      else
        base_params
      end

    # Add media type if not "all"
    params =
      if search_context.media_type != "all" do
        [{"type", search_context.media_type} | params]
      else
        params
      end

    # Add sort if not "relevance"
    params =
      if search_context.sort_by != "relevance" do
        [{"sort", search_context.sort_by} | params]
      else
        params
      end

    # Add page if not "1"
    params =
      if search_context.page != "1" do
        [{"page", search_context.page} | params]
      else
        params
      end

    # Build the final URL
    if params == [] do
      "/search"
    else
      query_string = URI.encode_query(params)
      "/search?#{query_string}"
    end
  end
end
