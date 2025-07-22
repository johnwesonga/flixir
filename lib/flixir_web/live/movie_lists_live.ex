defmodule FlixirWeb.MovieListsLive do
  @moduledoc """
  LiveView for displaying curated movie lists.

  This module handles the display of different movie list types including popular,
  trending, top-rated, upcoming, and now playing movies. It provides navigation
  between list types, pagination, and error handling following established patterns.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.AppLayout
  alias Flixir.Media
  require Logger

  @valid_list_types [:popular, :trending, :top_rated, :upcoming, :now_playing]
  @default_list_type :popular

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_list, @default_list_type)
      |> assign(:movies, [])
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:page, 1)
      |> assign(:has_more, false)
      |> assign(:page_title, "Movies")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    list_type = parse_list_type(Map.get(params, "list_type"))
    page = parse_page(Map.get(params, "page", "1"))

    socket =
      socket
      |> assign(:current_list, list_type)
      |> assign(:page, page)
      |> assign(:page_title, build_page_title(list_type))

    # Load movies for the current list type and page
    socket = load_movies(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_list", %{"list_type" => list_type_str}, socket) do
    list_type = parse_list_type(list_type_str)

    socket =
      socket
      |> assign(:current_list, list_type)
      |> assign(:page, 1)
      |> assign(:movies, [])
      |> assign(:error, nil)
      |> push_patch(to: build_url(list_type, 1))

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more", %{"page" => page_str}, socket) do
    page = parse_page(page_str)

    socket =
      socket
      |> assign(:page, page)
      |> assign(:loading, true)
      |> load_movies(append: true)
      |> update_url()

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1

    socket =
      socket
      |> assign(:page, next_page)
      |> assign(:loading, true)
      |> load_movies(append: true)
      |> update_url()

    {:noreply, socket}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    socket =
      socket
      |> assign(:error, nil)
      |> assign(:loading, true)
      |> load_movies()

    {:noreply, socket}
  end

  # Private Functions

  defp load_movies(socket, opts \\ []) do
    list_type = socket.assigns.current_list
    page = socket.assigns.page
    append = Keyword.get(opts, :append, false)

    socket = assign(socket, :loading, true)

    api_opts = [
      page: page,
      return_format: :map
    ]

    # Add time_window for trending movies
    api_opts =
      if list_type == :trending do
        Keyword.put(api_opts, :time_window, "week")
      else
        api_opts
      end

    result =
      case list_type do
        :popular -> Media.get_popular_movies(api_opts)
        :trending -> Media.get_trending_movies(api_opts)
        :top_rated -> Media.get_top_rated_movies(api_opts)
        :upcoming -> Media.get_upcoming_movies(api_opts)
        :now_playing -> Media.get_now_playing_movies(api_opts)
      end

    case result do
      {:ok, %{results: new_movies, has_more: has_more}} ->
        existing_movies = if append, do: socket.assigns.movies, else: []
        all_movies = existing_movies ++ new_movies

        socket
        |> assign(:movies, all_movies)
        |> assign(:has_more, has_more)
        |> assign(:loading, false)
        |> assign(:error, nil)

      {:ok, new_movies} when is_list(new_movies) ->
        # Fallback for backward compatibility
        existing_movies = if append, do: socket.assigns.movies, else: []
        all_movies = existing_movies ++ new_movies

        socket
        |> assign(:movies, all_movies)
        |> assign(:has_more, length(new_movies) >= 20)
        |> assign(:loading, false)
        |> assign(:error, nil)

      {:error, {:timeout, message}} ->
        Logger.warning("Movie list timeout for #{list_type}: #{message}")

        socket
        |> assign(:loading, false)
        |> assign(:error, :timeout)

      {:error, {:rate_limited, message}} ->
        Logger.warning("Rate limited for movie list #{list_type}: #{message}")

        socket
        |> assign(:loading, false)
        |> assign(:error, :rate_limited)

      {:error, {:unauthorized, message}} ->
        Logger.error("API authentication failed for movie list #{list_type}: #{message}")

        socket
        |> assign(:loading, false)
        |> assign(:error, :unauthorized)

      {:error, {:api_error, message}} ->
        Logger.error("API error for movie list #{list_type}: #{message}")

        socket
        |> assign(:loading, false)
        |> assign(:error, :api_error)

      {:error, {:network_error, message}} ->
        Logger.warning("Network error for movie list #{list_type}: #{message}")

        socket
        |> assign(:loading, false)
        |> assign(:error, :network_error)

      {:error, {:transformation_error, reason}} ->
        Logger.error("Data transformation error for movie list #{list_type}: #{inspect(reason)}")

        socket
        |> assign(:loading, false)
        |> assign(:error, :api_error)

      {:error, reason} ->
        Logger.error("Unexpected error for movie list #{list_type}: #{inspect(reason)}")

        socket
        |> assign(:loading, false)
        |> assign(:error, :api_error)
    end
  end

  defp parse_list_type(nil), do: @default_list_type
  defp parse_list_type("popular"), do: :popular
  defp parse_list_type("trending"), do: :trending
  defp parse_list_type("top-rated"), do: :top_rated
  defp parse_list_type("top_rated"), do: :top_rated
  defp parse_list_type("upcoming"), do: :upcoming
  defp parse_list_type("now-playing"), do: :now_playing
  defp parse_list_type("now_playing"), do: :now_playing

  defp parse_list_type(list_type) when is_atom(list_type) do
    if list_type in @valid_list_types, do: list_type, else: @default_list_type
  end

  defp parse_list_type(_), do: @default_list_type

  defp parse_page(page_str) when is_binary(page_str) do
    case Integer.parse(page_str) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page
  defp parse_page(_), do: 1

  defp build_page_title(:popular), do: "Popular Movies"
  defp build_page_title(:trending), do: "Trending Movies"
  defp build_page_title(:top_rated), do: "Top Rated Movies"
  defp build_page_title(:upcoming), do: "Upcoming Movies"
  defp build_page_title(:now_playing), do: "Now Playing Movies"

  defp build_url(list_type, page) do
    # Note: Routes will be added in task 6
    base_path =
      case list_type do
        :popular -> "/movies"
        _ -> "/movies/#{list_type_to_param(list_type)}"
      end

    if page > 1 do
      "#{base_path}?page=#{page}"
    else
      base_path
    end
  end

  defp list_type_to_param(:popular), do: "popular"
  defp list_type_to_param(:trending), do: "trending"
  defp list_type_to_param(:top_rated), do: "top-rated"
  defp list_type_to_param(:upcoming), do: "upcoming"
  defp list_type_to_param(:now_playing), do: "now-playing"

  defp update_url(socket) do
    list_type = socket.assigns.current_list
    page = socket.assigns.page

    push_patch(socket, to: build_url(list_type, page))
  end

  # Template helper functions

  defp list_type_label(:popular), do: "Popular Movies"
  defp list_type_label(:trending), do: "Trending Movies"
  defp list_type_label(:top_rated), do: "Top Rated Movies"
  defp list_type_label(:upcoming), do: "Upcoming Movies"
  defp list_type_label(:now_playing), do: "Now Playing Movies"

  defp page_description(:popular), do: "Discover the most popular movies right now"
  defp page_description(:trending), do: "See what's trending this week"
  defp page_description(:top_rated), do: "Explore the highest rated movies of all time"
  defp page_description(:upcoming), do: "Get ready for upcoming movie releases"
  defp page_description(:now_playing), do: "Find movies currently playing in theaters"



  defp error_message(:timeout),
    do: "The request timed out. Please check your connection and try again."

  defp error_message(:rate_limited), do: "Too many requests. Please wait a moment and try again."
  defp error_message(:unauthorized), do: "Unable to access movie data. Please try again later."

  defp error_message(:network_error),
    do: "Network connection error. Please check your internet connection."

  defp error_message(:api_error), do: "Unable to load movies from the service. Please try again."
  defp error_message(error) when is_binary(error), do: error
  defp error_message(_), do: "An unexpected error occurred. Please try again."

  defp poster_url(nil, _size), do: "/images/no-poster.svg"
  defp poster_url(poster_path, :small), do: "https://image.tmdb.org/t/p/w185#{poster_path}"
  defp poster_url(poster_path, :medium), do: "https://image.tmdb.org/t/p/w300#{poster_path}"
  defp poster_url(poster_path, :large), do: "https://image.tmdb.org/t/p/w500#{poster_path}"

  defp poster_srcset(nil), do: ""

  defp poster_srcset(poster_path) do
    [
      "#{poster_url(poster_path, :small)} 185w",
      "#{poster_url(poster_path, :medium)} 300w",
      "#{poster_url(poster_path, :large)} 500w"
    ]
    |> Enum.join(", ")
  end

  defp format_release_date(nil), do: "Unknown"
  defp format_release_date(%Date{} = date), do: Calendar.strftime(date, "%Y")

  defp format_release_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, parsed_date} -> Calendar.strftime(parsed_date, "%Y")
      _ -> "Unknown"
    end
  end

  defp format_release_date(_), do: "Unknown"

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length) <> "..."
    end
  end

  defp truncate_text(_, _), do: ""

  # Navigation helper function for the app layout

end
