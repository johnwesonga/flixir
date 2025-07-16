defmodule FlixirWeb.SearchLive do
  @moduledoc """
  LiveView module for movie and TV show search functionality.

  This module provides real-time search capabilities with filtering and sorting options.
  It manages search state including query, filters, results, and loading states.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.SearchComponents
  alias Flixir.Media
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:validation_error, nil)
      |> assign(:media_type, :all)
      |> assign(:sort_by, :relevance)
      |> assign(:page, 1)
      |> assign(:total_results, 0)
      |> assign(:search_performed, false)
      |> assign(:debounce_timer, nil)
      |> assign(:has_more_results, false)
      |> assign(:page_title, "Search")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = Map.get(params, "q", "")
    media_type = parse_media_type(Map.get(params, "type", "all"))
    sort_by = parse_sort_by(Map.get(params, "sort", "relevance"))
    page = parse_page(Map.get(params, "page", "1"))

    socket =
      socket
      |> assign(:query, query)
      |> assign(:media_type, media_type)
      |> assign(:sort_by, sort_by)
      |> assign(:page, page)
      |> assign(:validation_error, nil)

    # Set dynamic page title based on search query
    page_title =
      if String.trim(query) != "" do
        "Search: #{query}"
      else
        "Search"
      end

    socket = assign(socket, :page_title, page_title)

    # Perform search if query is present and valid
    socket =
      if String.trim(query) != "" do
        case validate_search_query(query) do
          {:ok, _validated_query} ->
            perform_search(socket)

          {:error, validation_message} ->
            socket
            |> assign(:validation_error, validation_message)
            |> assign(:results, [])
            |> assign(:search_performed, false)
            |> assign(:total_results, 0)
            |> assign(:loading, false)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    query = String.trim(query)

    socket =
      socket
      |> assign(:query, query)
      |> assign(:page, 1)
      |> assign(:error, nil)
      |> assign(:validation_error, nil)

    socket =
      case validate_search_query(query) do
        {:ok, validated_query} ->
          if validated_query == "" do
            socket
            |> assign(:results, [])
            |> assign(:search_performed, false)
            |> assign(:total_results, 0)
            |> assign(:loading, false)
            |> push_patch(to: ~p"/search")
          else
            socket
            |> assign(:loading, true)
            |> perform_search()
            |> update_url()
          end

        {:error, validation_message} ->
          socket
          |> assign(:validation_error, validation_message)
          |> assign(:results, [])
          |> assign(:search_performed, false)
          |> assign(:total_results, 0)
          |> assign(:loading, false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"media_type" => media_type}, socket) do
    media_type = parse_media_type(media_type)

    socket =
      socket
      |> assign(:media_type, media_type)
      |> assign(:page, 1)

    socket =
      if socket.assigns.query != "" do
        socket
        |> assign(:loading, true)
        |> perform_search()
        |> update_url()
      else
        socket |> update_url()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by = parse_sort_by(sort_by)

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:page, 1)

    socket =
      if socket.assigns.query != "" do
        socket
        |> assign(:loading, true)
        |> perform_search()
        |> update_url()
      else
        socket |> update_url()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1

    socket =
      socket
      |> assign(:page, next_page)
      |> assign(:loading, true)
      |> perform_search(append: true)
      |> update_url()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    socket =
      socket
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:search_performed, false)
      |> assign(:total_results, 0)
      |> assign(:error, nil)
      |> assign(:validation_error, nil)
      |> assign(:page, 1)
      |> push_patch(to: ~p"/search")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:media_type, :all)
      |> assign(:sort_by, :relevance)
      |> assign(:page, 1)

    socket =
      if socket.assigns.query != "" do
        socket
        |> assign(:loading, true)
        |> perform_search()
        |> update_url()
      else
        socket |> update_url()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_filters", %{"filters" => filters}, socket) do
    media_type = parse_media_type(Map.get(filters, "media_type", "all"))
    sort_by = parse_sort_by(Map.get(filters, "sort_by", "relevance"))

    socket =
      socket
      |> assign(:media_type, media_type)
      |> assign(:sort_by, sort_by)
      |> assign(:page, 1)

    socket =
      if socket.assigns.query != "" do
        socket
        |> assign(:loading, true)
        |> perform_search()
        |> update_url()
      else
        socket |> update_url()
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_search", %{"search" => %{"query" => query}}, socket) do
    # Cancel existing timer if present
    socket = cancel_debounce_timer(socket)

    query = String.trim(query)
    socket = assign(socket, :query, query)

    socket =
      case validate_search_query(query) do
        {:ok, validated_query} ->
          socket = assign(socket, :validation_error, nil)

          if validated_query == "" do
            # Clear results immediately for empty query
            socket
            |> assign(:results, [])
            |> assign(:search_performed, false)
            |> assign(:total_results, 0)
            |> assign(:loading, false)
            |> assign(:has_more_results, false)
            |> push_patch(to: ~p"/search")
          else
            # Start debounced search
            timer_ref = Process.send_after(self(), {:debounced_search, validated_query}, 300)
            assign(socket, :debounce_timer, timer_ref)
          end

        {:error, validation_message} ->
          socket
          |> assign(:validation_error, validation_message)
          |> assign(:results, [])
          |> assign(:search_performed, false)
          |> assign(:total_results, 0)
          |> assign(:loading, false)
          |> assign(:has_more_results, false)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("retry_search", _params, socket) do
    query = socket.assigns.query

    socket =
      socket
      |> assign(:error, nil)
      |> assign(:validation_error, nil)

    socket =
      case validate_search_query(query) do
        {:ok, _validated_query} ->
          if query == "" do
            socket
            |> assign(:results, [])
            |> assign(:search_performed, false)
            |> assign(:total_results, 0)
            |> assign(:loading, false)
          else
            socket
            |> assign(:loading, true)
            |> perform_search()
            |> update_url()
          end

        {:error, validation_message} ->
          socket
          |> assign(:validation_error, validation_message)
          |> assign(:results, [])
          |> assign(:search_performed, false)
          |> assign(:total_results, 0)
          |> assign(:loading, false)
      end

    {:noreply, socket}
  end

  # Private Functions

  defp perform_search(socket, opts \\ []) do
    query = socket.assigns.query
    media_type = socket.assigns.media_type
    sort_by = socket.assigns.sort_by
    page = socket.assigns.page
    append = Keyword.get(opts, :append, false)

    if String.trim(query) == "" do
      socket
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:search_performed, false)
      |> assign(:results, [])
      |> assign(:total_results, 0)
    else
      search_opts = [
        media_type: media_type,
        sort_by: sort_by,
        page: page
      ]

      case Media.search_content(query, search_opts ++ [return_format: :map]) do
        {:ok, %{results: results, has_more: has_more}} ->
          existing_results = if append, do: socket.assigns.results, else: []
          all_results = existing_results ++ results

          socket
          |> assign(:results, all_results)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:search_performed, true)
          |> assign(:total_results, length(all_results))
          |> assign(:has_more_results, has_more)

        {:ok, results} when is_list(results) ->
          # Fallback for backward compatibility
          existing_results = if append, do: socket.assigns.results, else: []
          all_results = existing_results ++ results

          socket
          |> assign(:results, all_results)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:search_performed, true)
          |> assign(:total_results, length(all_results))
          |> assign(:has_more_results, length(results) >= 20)

        {:error, {:timeout, message}} ->
          Logger.warning("Search timeout for query: #{query}")
          socket
          |> assign(:loading, false)
          |> assign(:error, message)
          |> assign(:search_performed, true)

        {:error, {:rate_limited, message}} ->
          Logger.warning("Rate limited for query: #{query}")
          socket
          |> assign(:loading, false)
          |> assign(:error, message)
          |> assign(:search_performed, true)

        {:error, {:network_error, message}} ->
          Logger.warning("Network error for query: #{query}")
          socket
          |> assign(:loading, false)
          |> assign(:error, message)
          |> assign(:search_performed, true)

        {:error, {:unauthorized, message}} ->
          Logger.error("API authentication failed for query: #{query}")
          socket
          |> assign(:loading, false)
          |> assign(:error, message)
          |> assign(:search_performed, true)

        {:error, {:api_error, message}} ->
          Logger.error("API error for query: #{query}")
          socket
          |> assign(:loading, false)
          |> assign(:error, message)
          |> assign(:search_performed, true)

        {:error, {:transformation_error, reason}} ->
          Logger.error("Data transformation error for query: #{query}: #{inspect(reason)}")
          socket
          |> assign(:loading, false)
          |> assign(:error, "Unable to process search results. Please try again.")
          |> assign(:search_performed, true)

        {:error, reason} ->
          Logger.error("Unexpected search error for query: #{query}: #{inspect(reason)}")
          socket
          |> assign(:loading, false)
          |> assign(:error, "An unexpected error occurred. Please try again.")
          |> assign(:search_performed, true)
      end
    end
  end

  defp update_url(socket) do
    params = build_url_params(socket.assigns)

    if map_size(params) == 0 do
      push_patch(socket, to: ~p"/search")
    else
      push_patch(socket, to: ~p"/search" <> "?" <> URI.encode_query(params))
    end
  end

  defp build_url_params(assigns) do
    params = %{}

    params =
      if assigns.query != "", do: Map.put(params, "q", assigns.query), else: params

    params =
      if assigns.media_type != :all,
        do: Map.put(params, "type", Atom.to_string(assigns.media_type)),
        else: params

    params =
      if assigns.sort_by != :relevance,
        do: Map.put(params, "sort", Atom.to_string(assigns.sort_by)),
        else: params

    params =
      if assigns.page > 1,
        do: Map.put(params, "page", Integer.to_string(assigns.page)),
        else: params

    params
  end

  defp parse_media_type("movie"), do: :movie
  defp parse_media_type("tv"), do: :tv
  defp parse_media_type(_), do: :all

  defp parse_sort_by("popularity"), do: :popularity
  defp parse_sort_by("release_date"), do: :release_date
  defp parse_sort_by("title"), do: :title
  defp parse_sort_by(_), do: :relevance

  defp parse_page(page_str) do
    case Integer.parse(page_str) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp format_sort_label(:relevance), do: "Relevance"
  defp format_sort_label(:popularity), do: "Popularity"
  defp format_sort_label(:release_date), do: "Release Date"
  defp format_sort_label(:title), do: "Title"

  defp validate_search_query(query) when is_binary(query) do
    trimmed = String.trim(query)

    cond do
      query != "" and trimmed == "" ->
        {:error, "Search query cannot contain only whitespace"}

      trimmed == "" ->
        {:ok, ""}

      String.length(trimmed) > 200 ->
        {:error, "Search query is too long (maximum 200 characters)"}

      String.length(trimmed) < 2 ->
        {:error, "Search query must be at least 2 characters long"}

      true ->
        {:ok, trimmed}
    end
  end

  defp validate_search_query(_), do: {:error, "Search query must be a string"}

  # Handle debounced search message
  @impl true
  def handle_info({:debounced_search, query}, socket) do
    # Clear the timer reference since it has fired
    socket = assign(socket, :debounce_timer, nil)

    # Only perform search if the query still matches current state
    if socket.assigns.query == query do
      socket =
        socket
        |> assign(:loading, true)
        |> assign(:page, 1)
        |> perform_search()
        |> update_url()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp cancel_debounce_timer(socket) do
    case socket.assigns.debounce_timer do
      nil -> socket
      timer_ref ->
        Process.cancel_timer(timer_ref)
        assign(socket, :debounce_timer, nil)
    end
  end
end
