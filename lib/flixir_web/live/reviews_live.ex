defmodule FlixirWeb.ReviewsLive do
  @moduledoc """
  LiveView for displaying movie and TV show reviews.

  This module handles the display of reviews with filtering, sorting, and pagination.
  Future implementation for the reviews section.
  """

  use FlixirWeb, :live_view
  import FlixirWeb.{AppLayout}
  #alias Flixir.Reviews
  require Logger


  @default_filter_type :recent

  @impl true
  def mount(_params, _session, socket) do
    # Authentication state is now handled by the on_mount hook
    socket =
      socket
      |> assign(:current_filter, @default_filter_type)
      |> assign(:reviews, [])
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:page, 1)
      |> assign(:has_more, false)
      |> assign(:page_title, "Reviews")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filter_type = parse_filter_type(Map.get(params, "filter"))
    page = parse_page(Map.get(params, "page", "1"))

    socket =
      socket
      |> assign(:current_filter, filter_type)
      |> assign(:page, page)
      |> assign(:page_title, build_page_title(filter_type))

    # Load reviews for the current filter type and page
    socket = load_reviews(socket)

    {:noreply, socket}
  end

  # Private helper functions
  defp parse_filter_type(nil), do: @default_filter_type
  defp parse_filter_type("recent"), do: :recent
  defp parse_filter_type("popular"), do: :popular
  defp parse_filter_type("movies"), do: :movies
  defp parse_filter_type("tv"), do: :tv
  defp parse_filter_type("top-rated"), do: :top_rated
  defp parse_filter_type("top_rated"), do: :top_rated
  defp parse_filter_type(_), do: @default_filter_type

  defp parse_page(page_str) when is_binary(page_str) do
    case Integer.parse(page_str) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp build_page_title(:recent), do: "Recent Reviews"
  defp build_page_title(:popular), do: "Popular Reviews"
  defp build_page_title(:movies), do: "Movie Reviews"
  defp build_page_title(:tv), do: "TV Show Reviews"
  defp build_page_title(:top_rated), do: "Top Rated Reviews"

  defp load_reviews(socket) do
    # Future implementation - load reviews based on current filter
    assign(socket, :reviews, [])
  end

  defp filter_type_label(:recent), do: "Recent Reviews"
  defp filter_type_label(:popular), do: "Popular Reviews"
  defp filter_type_label(:movies), do: "Movie Reviews"
  defp filter_type_label(:tv), do: "TV Show Reviews"
  defp filter_type_label(:top_rated), do: "Top Rated Reviews"

  defp filter_description(:recent), do: "See the latest movie and TV show reviews"
  defp filter_description(:popular), do: "Discover the most liked reviews from our community"
  defp filter_description(:movies), do: "Browse reviews for movies only"
  defp filter_description(:tv), do: "Browse reviews for TV shows only"
  defp filter_description(:top_rated), do: "Find reviews for the highest rated content"
end
