defmodule FlixirWeb.MovieListComponents do
  @moduledoc """
  Movie list UI components for displaying curated movie lists.

  This module contains reusable components for displaying movie lists such as
  popular, trending, top-rated, upcoming, and now playing movies in a consistent
  and responsive manner.
  """

  use FlixirWeb, :html

  @doc """
  Renders the main movie lists container with navigation and content.

  ## Examples

      <.movie_lists_container
        current_list={:popular}
        movies={movies}
        loading={false}
        error={nil}
        has_more={true}
        page={1}
      />
  """
  attr :current_list, :atom, required: true, doc: "Current active list type"
  attr :movies, :list, required: true, doc: "List of movie results"
  attr :loading, :boolean, default: false, doc: "Whether content is loading"
  attr :error, :string, default: nil, doc: "Error message if any"
  attr :has_more, :boolean, default: false, doc: "Whether more pages are available"
  attr :page, :integer, default: 1, doc: "Current page number"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def movie_lists_container(assigns) do
    ~H"""
    <div class={["max-w-7xl mx-auto px-4 sm:px-6 lg:px-8", @class]} data-testid="movie-lists-container">
      <!-- Page Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Movies</h1>
        <p class="text-gray-600">Discover popular movies, trending content, and upcoming releases</p>
      </div>

      <!-- List Navigation -->
      <.list_navigation current_list={@current_list} />

      <!-- Content Area -->
      <div class="mt-8">
        <%= cond do %>
          <% @error -> %>
            <.error_state error={@error} current_list={@current_list} />
          <% @loading and Enum.empty?(@movies) -> %>
            <.loading_state />
          <% Enum.empty?(@movies) and not @loading -> %>
            <.empty_state current_list={@current_list} />
          <% true -> %>
            <.movie_grid movies={@movies} current_list={@current_list} />
            <%= if @has_more do %>
              <.load_more_section loading={@loading} page={@page} />
            <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders navigation tabs for switching between different movie list types.

  ## Examples

      <.list_navigation current_list={:popular} />
  """
  attr :current_list, :atom, required: true, doc: "Current active list type"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def list_navigation(assigns) do
    ~H"""
    <nav class={["border-b border-gray-200", @class]} data-testid="list-navigation">
      <div class="flex space-x-8 overflow-x-auto">
        <.nav_tab
          list_type={:popular}
          current_list={@current_list}
          label="Popular"
          description="Most popular movies"
        />
        <.nav_tab
          list_type={:trending}
          current_list={@current_list}
          label="Trending"
          description="Trending this week"
        />
        <.nav_tab
          list_type={:top_rated}
          current_list={@current_list}
          label="Top Rated"
          description="Highest rated movies"
        />
        <.nav_tab
          list_type={:upcoming}
          current_list={@current_list}
          label="Upcoming"
          description="Coming soon"
        />
        <.nav_tab
          list_type={:now_playing}
          current_list={@current_list}
          label="Now Playing"
          description="In theaters now"
        />
      </div>
    </nav>
    """
  end

  @doc """
  Renders a responsive grid layout for movie cards.

  ## Examples

      <.movie_grid movies={movies} current_list={:popular} />
  """
  attr :movies, :list, required: true, doc: "List of movie results"
  attr :current_list, :atom, required: true, doc: "Current list type for context"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def movie_grid(assigns) do
    ~H"""
    <div
      class={[
        "grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6",
        @class
      ]}
      data-testid="movie-grid"
    >
      <%= for movie <- @movies do %>
        <.movie_card movie={movie} current_list={@current_list} />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an individual movie card with poster, title, rating, and release date.

  ## Examples

      <.movie_card movie={movie} current_list={:popular} />
  """
  attr :movie, :map, required: true, doc: "Movie data"
  attr :current_list, :atom, required: true, doc: "Current list type for context"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def movie_card(assigns) do
    # Build navigation params to preserve list context
    assigns = assign(assigns, :nav_params, build_nav_params(assigns))

    ~H"""
    <.link
      navigate={~p"/movie/#{@movie.id}?#{@nav_params}"}
      class={[
        "block bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-all duration-200 group cursor-pointer transform hover:-translate-y-1",
        @class
      ]}
      data-testid="movie-card"
    >
      <!-- Poster Image -->
      <div class="aspect-[2/3] bg-gray-200 relative overflow-hidden">
        <img
          src={poster_url(@movie.poster_path, :small)}
          srcset={poster_srcset(@movie.poster_path)}
          sizes="(max-width: 640px) 50vw, (max-width: 768px) 33vw, (max-width: 1024px) 25vw, 20vw"
          alt={"#{@movie.title} poster"}
          class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
          loading="lazy"
          decoding="async"
          onerror="this.src='/images/no-poster.svg'"
        />

        <!-- Rating Badge -->
        <%= if @movie.vote_average > 0 do %>
          <div class="absolute top-2 right-2">
            <.rating_badge rating={@movie.vote_average} />
          </div>
        <% end %>

        <!-- List Type Indicator -->
        <%= if @current_list in [:trending, :upcoming] do %>
          <div class="absolute bottom-2 left-2">
            <.list_indicator list_type={@current_list} />
          </div>
        <% end %>
      </div>

      <!-- Movie Info -->
      <div class="p-4">
        <h3
          class="font-semibold text-gray-900 mb-2 line-clamp-2 group-hover:text-blue-600 transition-colors leading-tight"
          title={@movie.title}
        >
          {@movie.title}
        </h3>

        <div class="flex items-center justify-between text-sm text-gray-600 mb-2">
          <span class="font-medium">{format_release_date(@movie.release_date)}</span>
          <%= if @movie.popularity > 100 do %>
            <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded-full font-medium">
              Popular
            </span>
          <% end %>
        </div>

        <%= if @movie.overview do %>
          <p class="text-sm text-gray-600 line-clamp-3 leading-relaxed">
            {truncate_text(@movie.overview, 100)}
          </p>
        <% end %>
      </div>
    </.link>
    """
  end

  # Private components

  defp nav_tab(assigns) do
    ~H"""
    <.link
      navigate={~p"/movies/#{@list_type}"}
      class={[
        "flex flex-col items-center py-4 px-1 border-b-2 font-medium text-sm whitespace-nowrap transition-colors min-w-0",
        if(@current_list == @list_type,
          do: "border-blue-500 text-blue-600",
          else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
        )
      ]}
      data-testid={"nav-tab-#{@list_type}"}
    >
      <span class="font-semibold">{@label}</span>
      <span class="text-xs text-gray-500 mt-1">{@description}</span>
    </.link>
    """
  end

  defp rating_badge(assigns) do
    ~H"""
    <div
      class="flex items-center bg-black bg-opacity-75 text-white px-2 py-1 rounded-full text-xs font-medium backdrop-blur-sm"
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

  defp list_indicator(assigns) do
    ~H"""
    <span
      class={[
        "px-2 py-1 text-xs font-medium rounded-full shadow-sm backdrop-blur-sm",
        case @list_type do
          :trending -> "bg-green-500 bg-opacity-90 text-white"
          :upcoming -> "bg-purple-500 bg-opacity-90 text-white"
          _ -> "bg-gray-500 bg-opacity-90 text-white"
        end
      ]}
      data-testid="list-indicator"
    >
      {case @list_type do
        :trending -> "Trending"
        :upcoming -> "Coming Soon"
        _ -> ""
      end}
    </span>
    """
  end

  defp load_more_section(assigns) do
    ~H"""
    <div class="mt-12 text-center" data-testid="load-more-section">
      <%= if @loading do %>
        <div class="inline-flex items-center px-6 py-3 text-gray-600">
          <svg
            class="animate-spin -ml-1 mr-3 h-5 w-5"
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
          <span class="font-medium">Loading more movies...</span>
        </div>
      <% else %>
        <button
          phx-click="load_more"
          phx-value-page={@page + 1}
          class="px-8 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium shadow-sm hover:shadow-md"
        >
          Load More Movies
        </button>
      <% end %>
    </div>
    """
  end

  defp loading_state(assigns) do
    ~H"""
    <div data-testid="loading-state">
      <!-- Loading message -->
      <div class="text-center py-8 mb-8">
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
          <span class="text-lg font-medium">Loading movies...</span>
        </div>
      </div>

      <!-- Skeleton grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6">
        <%= for _i <- 1..20 do %>
          <.skeleton_movie_card />
        <% end %>
      </div>
    </div>
    """
  end

  defp skeleton_movie_card(assigns) do
    ~H"""
    <div
      class="bg-white rounded-lg shadow-md overflow-hidden animate-pulse"
      data-testid="skeleton-movie-card"
    >
      <!-- Skeleton Poster -->
      <div class="aspect-[2/3] bg-gray-300"></div>

      <!-- Skeleton Content -->
      <div class="p-4">
        <!-- Title skeleton -->
        <div class="h-4 bg-gray-300 rounded mb-2"></div>
        <div class="h-4 bg-gray-300 rounded w-3/4 mb-3"></div>

        <!-- Date and popularity skeleton -->
        <div class="flex justify-between mb-3">
          <div class="h-3 bg-gray-300 rounded w-16"></div>
          <div class="h-3 bg-gray-300 rounded w-12"></div>
        </div>

        <!-- Description skeleton -->
        <div class="space-y-2">
          <div class="h-3 bg-gray-300 rounded"></div>
          <div class="h-3 bg-gray-300 rounded"></div>
          <div class="h-3 bg-gray-300 rounded w-2/3"></div>
        </div>
      </div>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="text-center py-16 px-4" data-testid="empty-state">
      <!-- Empty state icon -->
      <div class="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
        <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 110 2h-1v12a2 2 0 01-2 2H6a2 2 0 01-2-2V6H3a1 1 0 110-2h4zM9 6v10h6V6H9z"
          >
          </path>
        </svg>
      </div>

      <!-- Empty state content -->
      <h3 class="text-xl font-semibold text-gray-900 mb-2">No movies found</h3>
      <p class="text-gray-600 mb-6 max-w-md mx-auto">
        We couldn't find any {list_type_label(@current_list) |> String.downcase()} at the moment.
      </p>

      <!-- Retry button -->
      <button
        phx-click="retry"
        class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
      >
        Try Again
      </button>
    </div>
    """
  end

  defp error_state(assigns) do
    ~H"""
    <div class="text-center py-16 px-4" data-testid="error-state">
      <!-- Error icon -->
      <div class="mx-auto w-24 h-24 bg-red-100 rounded-full flex items-center justify-center mb-6">
        <svg class="w-12 h-12 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z"
          >
          </path>
        </svg>
      </div>

      <!-- Error content -->
      <h3 class="text-xl font-semibold text-gray-900 mb-2">Something went wrong</h3>
      <p class="text-gray-600 mb-6 max-w-md mx-auto">
        {error_message(@error)}
      </p>

      <!-- Retry button -->
      <button
        phx-click="retry"
        class="px-6 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium"
      >
        Try Again
      </button>
    </div>
    """
  end

  # Private helper functions

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

  defp list_type_label(:popular), do: "Popular movies"
  defp list_type_label(:trending), do: "Trending movies"
  defp list_type_label(:top_rated), do: "Top rated movies"
  defp list_type_label(:upcoming), do: "Upcoming movies"
  defp list_type_label(:now_playing), do: "Now playing movies"

  defp build_nav_params(assigns) do
    %{"from" => Atom.to_string(assigns.current_list)}
  end

  defp error_message(:timeout), do: "The request timed out. Please check your connection and try again."
  defp error_message(:rate_limited), do: "Too many requests. Please wait a moment and try again."
  defp error_message(:unauthorized), do: "Unable to access movie data. Please try again later."
  defp error_message(:network_error), do: "Network connection error. Please check your internet connection."
  defp error_message(:api_error), do: "Unable to load movies from the service. Please try again."
  defp error_message(error) when is_binary(error), do: error
  defp error_message(_), do: "An unexpected error occurred. Please try again."
end
