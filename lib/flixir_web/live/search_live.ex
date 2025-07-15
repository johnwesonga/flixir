defmodule FlixirWeb.SearchLive do
  @moduledoc """
  LiveView module for movie and TV show search functionality.

  This module provides real-time search capabilities with filtering and sorting options.
  It manages search state including query, filters, results, and loading states.
  """

  use FlixirWeb, :live_view
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
      |> assign(:media_type, :all)
      |> assign(:sort_by, :relevance)
      |> assign(:page, 1)
      |> assign(:total_results, 0)
      |> assign(:search_performed, false)

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

    # Perform search if query is present
    socket =
      if String.trim(query) != "" do
        perform_search(socket)
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

    socket =
      if query == "" do
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
      |> assign(:page, 1)
      |> push_patch(to: ~p"/search")

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

      case Media.search_content(query, search_opts) do
        {:ok, results} ->
          existing_results = if append, do: socket.assigns.results, else: []
          all_results = existing_results ++ results

          socket
          |> assign(:results, all_results)
          |> assign(:loading, false)
          |> assign(:error, nil)
          |> assign(:search_performed, true)
          |> assign(:total_results, length(all_results))

        {:error, {:timeout, message}} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, message)

        {:error, {:rate_limited, message}} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, message)

        {:error, {:network_error, message}} ->
          socket
          |> assign(:loading, false)
          |> assign(:error, message)

        {:error, reason} ->
          Logger.error("Search failed: #{inspect(reason)}")
          socket
          |> assign(:loading, false)
          |> assign(:error, "Search failed. Please try again.")
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

  defp media_type_label(:all), do: "All"
  defp media_type_label(:movie), do: "Movies"
  defp media_type_label(:tv), do: "TV Shows"



  defp format_release_date(nil), do: "Unknown"
  defp format_release_date(%Date{} = date) do
    Calendar.strftime(date, "%Y")
  end
  defp format_release_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, parsed_date} -> Calendar.strftime(parsed_date, "%Y")
      _ -> "Unknown"
    end
  end
  defp format_release_date(_), do: "Unknown"

  defp poster_url(nil), do: "/images/no-poster.png"
  defp poster_url(poster_path) do
    "https://image.tmdb.org/t/p/w300#{poster_path}"
  end

  defp truncate_text(text, max_length) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length) <> "..."
    end
  end
end
