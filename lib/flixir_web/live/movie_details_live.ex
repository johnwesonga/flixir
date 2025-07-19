defmodule FlixirWeb.MovieDetailsLive do
  @moduledoc """
  LiveView for displaying movie and TV show details with reviews.

  This module handles the display of media details along with user reviews,
  including filtering, sorting, and pagination functionality.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.ReviewComponents
  import FlixirWeb.ReviewFilters
  alias Flixir.{Media, Reviews}
  require Logger

  @impl true
  def mount(%{"type" => media_type, "id" => media_id}, _session, socket) do
    media_id = String.to_integer(media_id)

    socket =
      socket
      |> assign(:media_type, media_type)
      |> assign(:media_id, media_id)
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

    # Load media details and reviews
    socket =
      socket
      |> load_media_details()
      |> load_reviews()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_filters", params, socket) do
    action = Map.get(params, "action")

    socket = case action do
      "sort" ->
        sort_by = String.to_atom(Map.get(params, "sort_by", "date"))
        update_filter(socket, :sort_by, sort_by)

      "toggle_sort_order" ->
        current_order = Map.get(socket.assigns.review_filters, :sort_order, :desc)
        new_order = if current_order == :desc, do: :asc, else: :desc
        update_filter(socket, :sort_order, new_order)

      "filter_rating" ->
        rating_filter = parse_rating_filter(Map.get(params, "filter_by_rating"))
        update_filter(socket, :filter_by_rating, rating_filter)

      "filter_author" ->
        author_filter = Map.get(params, "author_filter")
        author_filter = if author_filter && String.trim(author_filter) == "", do: nil, else: author_filter
        update_filter(socket, :author_filter, author_filter)

      "filter_content" ->
        content_filter = Map.get(params, "content_filter")
        content_filter = if content_filter && String.trim(content_filter) == "", do: nil, else: content_filter
        update_filter(socket, :content_filter, content_filter)

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

      _ ->
        socket
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

  defp load_media_details(socket) do
    media_type = socket.assigns.media_type
    media_id = socket.assigns.media_id

    # Convert string media_type to atom and fix parameter order
    media_type_atom = case media_type do
      "movie" -> :movie
      "tv" -> :tv
      _ -> :movie  # fallback
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
  defp format_error_message({:transport_error, _}), do: "Network error. Please check your connection."
  defp format_error_message({:unexpected_status, status}), do: "Service error (#{status}). Please try again later."
  defp format_error_message(%{__exception__: true}), do: "An unexpected error occurred. Please try again."
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
end
