defmodule FlixirWeb.MainNavigation do
  @moduledoc """
  Main navigation component for the Flixir application.

  Provides unified navigation across search, movie lists, and reviews.
  """

  use FlixirWeb, :html

  @doc """
  Renders the main navigation bar with primary sections.
  """
  attr :current_section, :atom,
    default: :search,
    doc: "Current active section (:search, :movies, :reviews)"

  attr :current_subsection, :atom, default: nil, doc: "Current active subsection within a section"
  attr :class, :string, default: ""
  attr :current_user, :map, default: nil, doc: "Current authenticated user data"
  attr :authenticated?, :boolean, default: false, doc: "Whether user is authenticated"

  def main_nav(assigns) do
    # Debug logging to see what authentication state we're receiving
    require Logger

    Logger.debug("Main navigation rendering", %{
      authenticated?: assigns[:authenticated?],
      has_current_user: not is_nil(assigns[:current_user]),
      current_user: inspect(assigns[:current_user])
    })

    ~H"""
    <nav class={["bg-white shadow-sm border-b border-gray-200", @class]} data-testid="main-navigation">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <!-- Logo/Brand -->
          <div class="flex items-center">
            <.link
              navigate="/"
              class="flex items-center space-x-2 text-xl font-bold text-gray-900 hover:text-blue-600 transition-colors"
            >
              <.icon name="hero-film" class="h-8 w-8 text-blue-600" />
              <span>Flixir</span>
            </.link>
          </div>

    <!-- Main Navigation -->
          <div class="flex items-center space-x-8">
            <!-- Search -->
            <.nav_item
              navigate="/search"
              active={@current_section == :search}
              icon="hero-magnifying-glass"
              label="Search"
              description="Find movies & TV shows"
            />

    <!-- Movies -->
            <.nav_item
              navigate="/movies"
              active={@current_section == :movies}
              icon="hero-film"
              label="Movies"
              description="Browse movie collections"
            />

    <!-- Reviews -->
            <.nav_item
              navigate="/reviews"
              active={@current_section == :reviews}
              icon="hero-star"
              label="Reviews"
              description="Latest movie reviews"
            />

    <!-- Authentication Section -->
            <div class="flex items-center ml-6 pl-6 border-l border-gray-200">
              <%= if @authenticated? do %>
                <.user_menu current_user={@current_user} />
              <% else %>
                <.login_button />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Renders a secondary navigation bar for subsections.
  """
  attr :items, :list,
    required: true,
    doc: "List of navigation items {key, label, url, description}"

  attr :current, :atom, required: true, doc: "Current active item key"
  attr :class, :string, default: ""

  def sub_nav(assigns) do
    ~H"""
    <nav class={["bg-gray-50 border-b border-gray-200", @class]} data-testid="sub-navigation">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex space-x-8 overflow-x-auto scrollbar-hide">
          <%= for {key, label, url, description} <- @items do %>
            <.link
              navigate={url}
              class={[
                "flex flex-col items-center py-4 px-1 border-b-2 font-medium text-sm whitespace-nowrap transition-colors min-w-0 group",
                if(@current == key,
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
    """
  end

  @doc """
  Renders a user menu dropdown for authenticated users.
  """
  attr :current_user, :map, required: true

  def user_menu(assigns) do
    ~H"""
    <div class="relative" data-testid="user-menu">
      <!-- User Menu Button -->
      <button
        type="button"
        class="flex items-center space-x-2 px-3 py-2 rounded-lg text-gray-700 hover:text-gray-900 hover:bg-gray-50 transition-colors"
        phx-click={JS.toggle(to: "#user-dropdown")}
        data-testid="user-menu-button"
      >
        <.icon name="hero-user-circle" class="h-6 w-6 text-gray-400" />
        <span class="text-sm font-medium">{@current_user["username"]}</span>
        <.icon name="hero-chevron-down" class="h-4 w-4 text-gray-400" />
      </button>

    <!-- Dropdown Menu -->
      <div
        id="user-dropdown"
        class="hidden absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg ring-1 ring-black ring-opacity-5 z-50"
        data-testid="user-dropdown"
      >
        <div class="py-1">
          <!-- User Info -->
          <div class="px-4 py-2 border-b border-gray-100">
            <p class="text-sm font-medium text-gray-900">{@current_user["username"]}</p>
            <%= if @current_user["name"] && @current_user["name"] != "" do %>
              <p class="text-xs text-gray-500">{@current_user["name"]}</p>
            <% end %>
          </div>

    <!-- Menu Items -->
          <.link
            navigate="/auth/logout"
            class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 hover:text-gray-900 transition-colors"
            data-testid="logout-link"
          >
            <div class="flex items-center space-x-2">
              <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" />
              <span>Logout</span>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a login button for unauthenticated users.
  """
  def login_button(assigns) do
    ~H"""
    <.link
      navigate="/auth/login"
      class="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
      data-testid="login-button"
    >
      <.icon name="hero-arrow-right-on-rectangle" class="h-4 w-4" />
      <span class="text-sm font-medium">Login</span>
    </.link>
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
      <.icon
        name={@icon}
        class={
        "h-6 w-6 mb-1 transition-colors " <>
        if(@active, do: "text-blue-600", else: "text-gray-400 group-hover:text-gray-600")
      }
      />
      <span class="text-sm font-medium">{@label}</span>
      <span class="text-xs text-gray-500 group-hover:text-gray-600 transition-colors">
        {@description}
      </span>
    </.link>
    """
  end
end
