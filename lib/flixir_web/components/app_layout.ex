defmodule FlixirWeb.AppLayout do
  @moduledoc """
  Application layout component with unified navigation.
  """

  use Phoenix.Component
  use Gettext, backend: FlixirWeb.Gettext
  import FlixirWeb.CoreComponents
  import FlixirWeb.MainNavigation

  @doc """
  Renders the main application layout with navigation.
  """
  attr :current_section, :atom, required: true
  attr :current_subsection, :atom, default: nil
  attr :show_sub_nav, :boolean, default: false
  attr :sub_nav_items, :list, default: []
  attr :page_title, :string, required: true
  attr :current_user, :map, default: nil
  attr :authenticated?, :boolean, default: false
  slot :inner_block, required: true

  def app_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Main Navigation -->
      <.main_nav
        current_section={@current_section}
        current_subsection={@current_subsection}
        current_user={@current_user}
        authenticated?={@authenticated?}
      />

      <!-- Sub Navigation (conditional) -->
      <%= if @show_sub_nav and length(@sub_nav_items) > 0 do %>
        <nav class="bg-gray-50 border-b border-gray-200" data-testid="sub-navigation">
          <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="flex space-x-8 overflow-x-auto scrollbar-hide">
              <%= for {key, label, url, description} <- @sub_nav_items do %>
                <.link
                  navigate={url}
                  class={[
                    "flex flex-col items-center py-4 px-1 border-b-2 font-medium text-sm whitespace-nowrap transition-colors min-w-0 group",
                    if((@current_subsection || :default) == key,
                      do: "border-blue-500 text-blue-600",
                      else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    )
                  ]}
                  data-testid={"sub-nav-#{key}"}
                >
                  <span class="font-semibold group-hover:text-current transition-colors">{label}</span>
                  <span class="text-xs text-gray-500 mt-1 group-hover:text-gray-600 transition-colors">
                    {description}
                  </span>
                </.link>
              <% end %>
            </div>
          </div>
        </nav>
      <% end %>

      <!-- Main Content -->
      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>

      <!-- Footer (optional) -->
      <footer class="bg-white border-t border-gray-200 mt-auto">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div class="flex justify-between items-center">
            <p class="text-sm text-gray-500">
              © 2024 Flixir. Discover movies and TV shows.
            </p>
            <div class="flex space-x-6">
              <.link navigate="/search" class="text-sm text-gray-500 hover:text-gray-700">
                Search
              </.link>
              <.link navigate="/movies" class="text-sm text-gray-500 hover:text-gray-700">
                Movies
              </.link>
              <.link navigate="/reviews" class="text-sm text-gray-500 hover:text-gray-700">
                Reviews
              </.link>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  # Private component for navigation items
  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :description, :string, required: true

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex flex-col items-center px-3 py-2 rounded-lg transition-all duration-200 group",
        if(@active,
          do: "bg-blue-50 text-blue-700",
          else: "text-gray-600 hover:text-gray-900 hover:bg-gray-50"
        )
      ]}
      data-testid={"main-nav-#{String.replace(@label, " ", "-") |> String.downcase()}"}
    >
      <.icon name={@icon} class={
        "h-6 w-6 mb-1 transition-colors " <>
        if(@active, do: "text-blue-600", else: "text-gray-400 group-hover:text-gray-600")
      } />
      <span class="text-sm font-medium">{@label}</span>
      <span class="text-xs text-gray-500 group-hover:text-gray-600 transition-colors">
        {@description}
      </span>
    </.link>
    """
  end

  @doc """
  Helper function to get movie list navigation items.
  """
  def movie_nav_items do
    [
      {:popular, "Popular", "/movies", "Most popular movies"},
      {:trending, "Trending", "/movies/trending", "Trending this week"},
      {:top_rated, "Top Rated", "/movies/top-rated", "Highest rated movies"},
      {:upcoming, "Upcoming", "/movies/upcoming", "Coming soon"},
      {:now_playing, "Now Playing", "/movies/now-playing", "In theaters now"}
    ]
  end

  @doc """
  Helper function to get review navigation items.
  """
  def review_nav_items do
    [
      {:recent, "Recent", "/reviews", "Latest reviews"},
      {:popular, "Popular", "/reviews/popular", "Most liked reviews"},
      {:movies, "Movies", "/reviews/movies", "Movie reviews only"},
      {:tv, "TV Shows", "/reviews/tv", "TV show reviews only"},
      {:top_rated, "Top Rated", "/reviews/top-rated", "Highest rated content"}
    ]
  end
end
