defmodule FlixirWeb.SearchComponents do
  @moduledoc """
  Search-related UI components for the movie and TV search functionality.

  This module contains reusable components for displaying search results,
  loading states, and empty states in a consistent and responsive manner.
  """

  use FlixirWeb, :html

  @doc """
  Renders a search result card component.

  ## Examples

      <.search_result_card result={result} />
  """
  attr :result, :map, required: true, doc: "The search result data"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :query, :string, default: "", doc: "Current search query"
  attr :media_type, :atom, default: :all, doc: "Current media type filter"
  attr :sort_by, :atom, default: :relevance, doc: "Current sort option"
  attr :page, :integer, default: 1, doc: "Current page number"

  def search_result_card(assigns) do
    # Build search context for back navigation and assign to assigns
    assigns = assign(assigns, :search_params, build_search_params(assigns))

    ~H"""
    <.link
      navigate={~p"/#{@result.media_type}/#{@result.id}?#{@search_params}"}
      class={[
        "block bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow duration-200 group cursor-pointer",
        @class
      ]}
      data-testid="search-result-card"
    >
      <!-- Poster Image -->
      <div class="aspect-[2/3] bg-gray-200 relative overflow-hidden">
        <img
          src={poster_url(@result.poster_path, :small)}
          srcset={poster_srcset(@result.poster_path)}
          sizes="(max-width: 640px) 50vw, (max-width: 768px) 33vw, (max-width: 1024px) 25vw, 20vw"
          alt={"#{@result.title} poster"}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
          loading="lazy"
          decoding="async"
          onerror="this.src='/images/no-poster.svg'"
        />
        <!-- Media Type Badge -->
        <div class="absolute top-2 right-2">
          <.media_type_badge type={@result.media_type} />
        </div>
        <!-- Rating Badge -->
        <%= if @result.vote_average > 0 do %>
          <div class="absolute bottom-2 left-2">
            <.rating_badge rating={@result.vote_average} />
          </div>
        <% end %>
      </div>

    <!-- Content Info -->
      <div class="p-4">
        <h3
          class="font-semibold text-gray-900 mb-1 line-clamp-2 group-hover:text-blue-600 transition-colors"
          title={@result.title}
        >
          {@result.title}
        </h3>

        <div class="flex items-center justify-between text-sm text-gray-600 mb-2">
          <span class="font-medium">{format_release_date(@result.release_date)}</span>
          <%= if @result.popularity > 0 do %>
            <span class="text-xs bg-gray-100 px-2 py-1 rounded-full">
              Popular
            </span>
          <% end %>
        </div>

        <%= if @result.overview do %>
          <p class="text-sm text-gray-600 line-clamp-3 leading-relaxed">
            {truncate_text(@result.overview, 120)}
          </p>
        <% end %>
      </div>
    </.link>
    """
  end

  @doc """
  Renders a media type badge.

  ## Examples

      <.media_type_badge type={:movie} />
      <.media_type_badge type={:tv} />
  """
  attr :type, :atom, required: true, doc: "The media type (:movie or :tv)"

  def media_type_badge(assigns) do
    ~H"""
    <span
      class={[
        "px-2 py-1 text-xs font-medium rounded-full shadow-sm",
        if(@type == :movie,
          do: "bg-blue-100 text-blue-800 border border-blue-200",
          else: "bg-green-100 text-green-800 border border-green-200"
        )
      ]}
      data-testid="media-type-badge"
    >
      {if @type == :movie, do: "Movie", else: "TV Show"}
    </span>
    """
  end

  @doc """
  Renders a rating badge with star icon.

  ## Examples

      <.rating_badge rating={7.5} />
  """
  attr :rating, :float, required: true, doc: "The rating value"

  def rating_badge(assigns) do
    ~H"""
    <div
      class="flex items-center bg-black bg-opacity-70 text-white px-2 py-1 rounded-full text-xs font-medium"
      data-testid="rating-badge"
    >
      <svg class="w-3 h-3 text-yellow-400 mr-1" fill="currentColor" viewBox="0 0 20 20">
        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z">
        </path>
      </svg>
      <span>{Float.round(@rating, 1)}</span>
    </div>
    """
  end

  @doc """
  Renders a responsive grid layout for search results.

  ## Examples

      <.search_results_grid results={results} />
  """
  attr :results, :list, required: true, doc: "List of search results"
  attr :loading, :boolean, default: false, doc: "Whether results are loading"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :query, :string, default: "", doc: "Current search query"
  attr :media_type, :atom, default: :all, doc: "Current media type filter"
  attr :sort_by, :atom, default: :relevance, doc: "Current sort option"
  attr :page, :integer, default: 1, doc: "Current page number"

  def search_results_grid(assigns) do
    ~H"""
    <div
      class={[
        "grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6",
        @class
      ]}
      data-testid="search-results-grid"
    >
      <%= for result <- @results do %>
        <.search_result_card
          result={result}
          query={@query}
          media_type={@media_type}
          sort_by={@sort_by}
          page={@page}
        />
      <% end %>

    <!-- Loading skeleton cards -->
      <%= if @loading do %>
        <%= for _i <- 1..10 do %>
          <.skeleton_card />
        <% end %>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a skeleton loading card for better UX during loading states.

  ## Examples

      <.skeleton_card />
  """
  def skeleton_card(assigns) do
    ~H"""
    <div
      class="bg-white rounded-lg shadow-md overflow-hidden animate-pulse"
      data-testid="skeleton-card"
    >
      <!-- Skeleton Poster -->
      <div class="aspect-[2/3] bg-gray-300"></div>

    <!-- Skeleton Content -->
      <div class="p-4">
        <!-- Title skeleton -->
        <div class="h-4 bg-gray-300 rounded mb-2"></div>
        <div class="h-4 bg-gray-300 rounded w-3/4 mb-2"></div>

    <!-- Date and rating skeleton -->
        <div class="flex justify-between mb-2">
          <div class="h-3 bg-gray-300 rounded w-16"></div>
          <div class="h-3 bg-gray-300 rounded w-12"></div>
        </div>

    <!-- Description skeleton -->
        <div class="space-y-1">
          <div class="h-3 bg-gray-300 rounded"></div>
          <div class="h-3 bg-gray-300 rounded"></div>
          <div class="h-3 bg-gray-300 rounded w-2/3"></div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an empty state component when no search results are found.

  ## Examples

      <.empty_search_state query="batman" media_type={:all} />
  """
  attr :query, :string, required: true, doc: "The search query that returned no results"
  attr :media_type, :atom, default: :all, doc: "The media type filter applied"

  attr :on_clear, :string,
    default: "clear_search",
    doc: "Phoenix event to trigger when clearing search"

  def empty_search_state(assigns) do
    ~H"""
    <div class="text-center py-16 px-4" data-testid="empty-search-state">
      <!-- Empty state icon -->
      <div class="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
        <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          >
          </path>
        </svg>
      </div>

    <!-- Empty state content -->
      <h3 class="text-xl font-semibold text-gray-900 mb-2">No results found</h3>
      <p class="text-gray-600 mb-6 max-w-md mx-auto">
        We couldn't find any {media_type_label(@media_type) |> String.downcase()} matching "<span class="font-medium text-gray-900"><%= @query %></span>"
      </p>

    <!-- Suggestions -->
      <div class="bg-gray-50 rounded-lg p-6 max-w-md mx-auto mb-6">
        <h4 class="font-medium text-gray-900 mb-3">Try these suggestions:</h4>
        <ul class="text-sm text-gray-600 space-y-1 text-left">
          <li>• Check your spelling</li>
          <li>• Try different keywords</li>
          <li>• Use more general terms</li>
          <li>• Remove filters to see more results</li>
        </ul>
      </div>

    <!-- Action button -->
      <button
        phx-click={@on_clear}
        class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
      >
        Start a new search
      </button>
    </div>
    """
  end

  @doc """
  Renders an initial search state when no search has been performed.

  ## Examples

      <.initial_search_state />
  """
  def initial_search_state(assigns) do
    ~H"""
    <div class="text-center py-20 px-4" data-testid="initial-search-state">
      <!-- Search icon -->
      <div class="mx-auto w-32 h-32 bg-gradient-to-br from-blue-100 to-purple-100 rounded-full flex items-center justify-center mb-8">
        <svg class="w-16 h-16 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          >
          </path>
        </svg>
      </div>

    <!-- Welcome content -->
      <h2 class="text-2xl font-bold text-gray-900 mb-3">Discover Movies & TV Shows</h2>
      <p class="text-gray-600 mb-8 max-w-lg mx-auto">
        Search through thousands of movies and TV shows to find your next favorite.
        Enter a title, actor, or keyword to get started.
      </p>

    <!-- Popular suggestions -->
      <div class="max-w-md mx-auto">
        <p class="text-sm font-medium text-gray-700 mb-3">Popular searches:</p>
        <div class="flex flex-wrap gap-2 justify-center">
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">Marvel</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">Breaking Bad</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">The Office</span>
          <span class="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm">Star Wars</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading state for the entire search results section.

  ## Examples

      <.search_loading_state />
  """
  def search_loading_state(assigns) do
    ~H"""
    <div class="text-center py-12" data-testid="search-loading-state">
      <div class="inline-flex items-center px-6 py-3 text-gray-600">
        <svg
          class="animate-spin -ml-1 mr-3 h-6 w-6"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
          </circle>
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          >
          </path>
        </svg>
        <span class="text-lg font-medium">Searching for great content...</span>
      </div>
    </div>
    """
  end

  # Private helper functions

  # defp poster_url(nil), do: "/images/no-poster.svg"
  # defp poster_url(poster_path) do
  #  "https://image.tmdb.org/t/p/w300#{poster_path}"
  # end

  defp poster_url(nil, _size), do: "/images/no-poster.svg"

  defp poster_url(poster_path, :small) do
    "https://image.tmdb.org/t/p/w185#{poster_path}"
  end

  defp poster_url(poster_path, :medium) do
    "https://image.tmdb.org/t/p/w300#{poster_path}"
  end

  defp poster_url(poster_path, :large) do
    "https://image.tmdb.org/t/p/w500#{poster_path}"
  end

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

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length) <> "..."
    end
  end

  defp truncate_text(_, _), do: ""

  defp media_type_label(:all), do: "content"
  defp media_type_label(:movie), do: "movies"
  defp media_type_label(:tv), do: "TV shows"

  defp build_search_params(assigns) do
    # Extract search context from assigns if available
    params = %{}

    # Add query parameter if present
    params = if Map.has_key?(assigns, :query) and assigns.query != "" do
      Map.put(params, "q", assigns.query)
    else
      params
    end

    # Add media type if not :all
    params = if Map.has_key?(assigns, :media_type) and assigns.media_type != :all do
      Map.put(params, "type", Atom.to_string(assigns.media_type))
    else
      params
    end

    # Add sort if not :relevance
    params = if Map.has_key?(assigns, :sort_by) and assigns.sort_by != :relevance do
      Map.put(params, "sort", Atom.to_string(assigns.sort_by))
    else
      params
    end

    # Add page if not 1
    params = if Map.has_key?(assigns, :page) and assigns.page != 1 do
      Map.put(params, "page", Integer.to_string(assigns.page))
    else
      params
    end

    params
  end
end
