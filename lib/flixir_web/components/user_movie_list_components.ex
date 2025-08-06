defmodule FlixirWeb.UserMovieListComponents do
  @moduledoc """
  User movie list UI components for displaying and managing personal movie lists.

  This module contains reusable components for displaying user-created movie lists,
  forms for creating and editing lists, and confirmation modals for destructive operations.
  """

  use FlixirWeb, :html
  import FlixirWeb.CoreComponents

  @doc """
  Renders the main user movie lists container with all user lists.

  ## Examples

      <.user_lists_container
        lists={lists}
        loading={false}
        error={nil}
        current_user={current_user}
      />
  """
  attr :lists, :list, required: true, doc: "List of user movie lists"
  attr :loading, :boolean, default: false, doc: "Whether content is loading"
  attr :error, :string, default: nil, doc: "Error message if any"
  attr :current_user, :map, default: nil, doc: "Current authenticated user"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def user_lists_container(assigns) do
    ~H"""
    <div class={["max-w-7xl mx-auto px-4 sm:px-6 lg:px-8", @class]} data-testid="user-lists-container">
      <!-- Page Header -->
      <div class="mb-8">
        <.header>
          My Movie Lists
          <:subtitle>
            Organize your movies into custom collections
          </:subtitle>
          <:actions>
            <.button phx-click="show_create_form" class="btn-primary">
              <.icon name="hero-plus" class="w-4 h-4 mr-2" />
              Create New List
            </.button>
          </:actions>
        </.header>
      </div>

      <!-- Content Area -->
      <div class="mt-8">
        <%= cond do %>
          <% @error -> %>
            <.error_state error={@error} />
          <% @loading and Enum.empty?(@lists) -> %>
            <.loading_state />
          <% Enum.empty?(@lists) and not @loading -> %>
            <.empty_lists_state />
          <% true -> %>
            <.lists_grid lists={@lists} />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a grid layout for user movie list cards.

  ## Examples

      <.lists_grid lists={lists} />
  """
  attr :lists, :list, required: true, doc: "List of user movie lists"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def lists_grid(assigns) do
    ~H"""
    <div
      class={[
        "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6",
        @class
      ]}
      data-testid="lists-grid"
    >
      <%= for list <- @lists do %>
        <.list_card list={list} />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an individual movie list card with name, description, movie count, and privacy status.

  ## Examples

      <.list_card list={list} />
  """
  attr :list, :map, required: true, doc: "Movie list data"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def list_card(assigns) do
    assigns = assign(assigns, :movie_count, length(assigns.list.list_items || []))

    ~H"""
    <div
      class={[
        "bg-white rounded-lg shadow-md border border-gray-200 overflow-hidden hover:shadow-lg transition-all duration-200 group cursor-pointer",
        @class
      ]}
      data-testid="list-card"
    >
      <!-- List Header -->
      <div class="p-6 pb-4">
        <div class="flex items-start justify-between mb-3">
          <div class="flex-1 min-w-0">
            <h3 class="text-lg font-semibold text-gray-900 truncate group-hover:text-blue-600 transition-colors">
              {@list.name}
            </h3>
            <%= if @list.description && String.trim(@list.description) != "" do %>
              <p class="text-sm text-gray-600 mt-1 line-clamp-2">
                {@list.description}
              </p>
            <% end %>
          </div>

          <!-- Privacy Status -->
          <div class="flex-shrink-0 ml-3">
            <%= if @list.is_public do %>
              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                <.icon name="hero-globe-alt" class="w-3 h-3 mr-1" />
                Public
              </span>
            <% else %>
              <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                <.icon name="hero-lock-closed" class="w-3 h-3 mr-1" />
                Private
              </span>
            <% end %>
          </div>
        </div>

        <!-- List Stats -->
        <div class="flex items-center justify-between text-sm text-gray-500">
          <div class="flex items-center">
            <.icon name="hero-film" class="w-4 h-4 mr-1" />
            <span>
              <%= ngettext("1 movie", "%{count} movies", @movie_count) %>
            </span>
          </div>
          <time datetime={NaiveDateTime.to_iso8601(@list.updated_at, :extended)}>
            Updated {format_relative_date(DateTime.from_naive!(@list.updated_at, "Etc/UTC"))}
          </time>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="px-6 py-4 bg-gray-50 border-t border-gray-100">
        <div class="flex items-center justify-between">
          <button
            type="button"
            phx-click="view_list"
            phx-value-list-id={@list.id}
            class="text-blue-600 hover:text-blue-800 text-sm font-medium transition-colors"
          >
            View List
          </button>

          <div class="flex items-center space-x-3">
            <button
              type="button"
              phx-click="edit_list"
              phx-value-list-id={@list.id}
              class="text-gray-600 hover:text-gray-800 text-sm font-medium transition-colors"
              data-testid="edit-list-button"
            >
              Edit
            </button>

            <%= if @movie_count > 0 do %>
              <button
                type="button"
                phx-click="show_clear_confirmation"
                phx-value-list-id={@list.id}
                class="text-orange-600 hover:text-orange-800 text-sm font-medium transition-colors"
                data-testid="clear-list-button"
              >
                Clear
              </button>
            <% end %>

            <button
              type="button"
              phx-click="show_delete_confirmation"
              phx-value-list-id={@list.id}
              class="text-red-600 hover:text-red-800 text-sm font-medium transition-colors"
              data-testid="delete-list-button"
            >
              Delete
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a form for creating or editing movie lists with validation feedback.

  ## Examples

      <.list_form
        form={form}
        action={:create}
        title="Create New List"
      />
  """
  attr :form, Phoenix.HTML.Form, required: true, doc: "The form struct"
  attr :action, :atom, required: true, values: [:create, :edit], doc: "Form action type"
  attr :title, :string, required: true, doc: "Form title"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def list_form(assigns) do
    ~H"""
    <div class={["bg-white rounded-lg shadow-lg border border-gray-200 p-6", @class]} data-testid="list-form">
      <div class="mb-6">
        <h2 class="text-xl font-semibold text-gray-900">{@title}</h2>
        <p class="text-sm text-gray-600 mt-1">
          <%= if @action == :create do %>
            Create a new movie list to organize your favorite films.
          <% else %>
            Update your list details and privacy settings.
          <% end %>
        </p>
      </div>

      <.form for={@form} phx-submit={if @action == :create, do: "create_list", else: "update_list"}>
        <!-- List Name -->
        <.input
          field={@form[:name]}
          type="text"
          label="List Name"
          placeholder="e.g., My Watchlist, Favorite Comedies"
          required
          maxlength="100"
        />

        <!-- Description -->
        <.input
          field={@form[:description]}
          type="textarea"
          label="Description (Optional)"
          placeholder="Describe what this list is about..."
          rows="3"
          maxlength="500"
        />

        <!-- Privacy Setting -->
        <.input
          field={@form[:is_public]}
          type="checkbox"
          label="Make this list public"
        />

        <div class="text-xs text-gray-500 mt-1 mb-4">
          Public lists can be viewed by other users, but only you can edit them.
        </div>

        <!-- Form Actions -->
        <div class="flex items-center justify-end space-x-3 pt-4 border-t border-gray-100">
          <button
            type="button"
            phx-click="cancel_form"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>

          <button
            type="submit"
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 transition-colors"
            data-testid="submit-list-form"
          >
            <%= if @action == :create, do: "Create List", else: "Update List" %>
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @doc """
  Renders list statistics display showing movie count, dates, and privacy status.

  ## Examples

      <.list_stats stats={stats} />
  """
  attr :stats, :map, required: true, doc: "List statistics data"
  attr :compact, :boolean, default: false, doc: "Whether to show compact version"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def list_stats(assigns) do
    ~H"""
    <div class={["bg-white rounded-lg border border-gray-200", @class]} data-testid="list-stats">
      <%= if @compact do %>
        <.compact_list_stats stats={@stats} />
      <% else %>
        <.full_list_stats stats={@stats} />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a confirmation modal for deleting a list.

  ## Examples

      <.delete_confirmation_modal
        show={true}
        list={list}
      />
  """
  attr :show, :boolean, required: true, doc: "Whether to show the modal"
  attr :list, :map, required: true, doc: "The list to be deleted"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def delete_confirmation_modal(assigns) do
    assigns = assign(assigns, :movie_count, length(assigns.list.list_items || []))

    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 overflow-y-auto"
      data-testid="delete-confirmation-modal"
    >
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"></div>

      <!-- Modal -->
      <div class="flex min-h-full items-center justify-center p-4">
        <div class={[
          "relative bg-white rounded-lg shadow-xl max-w-md w-full mx-auto",
          @class
        ]}>
          <div class="p-6">
            <!-- Icon -->
            <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-100 mb-4">
              <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-600" />
            </div>

            <!-- Content -->
            <div class="text-center">
              <h3 class="text-lg font-semibold text-gray-900 mb-2">
                Delete List
              </h3>
              <p class="text-sm text-gray-600 mb-4">
                Are you sure you want to delete "<strong>{@list.name}</strong>"?
                <%= if @movie_count > 0 do %>
                  This will permanently remove the list and all {ngettext("1 movie", "%{count} movies", @movie_count)} in it.
                <% else %>
                  This action cannot be undone.
                <% end %>
              </p>
            </div>

            <!-- Actions -->
            <div class="flex items-center justify-end space-x-3 mt-6">
              <button
                type="button"
                phx-click="cancel_delete"
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>

              <button
                type="button"
                phx-click="confirm_delete"
                phx-value-list-id={@list.id}
                class="px-4 py-2 text-sm font-medium text-white bg-red-600 border border-transparent rounded-md hover:bg-red-700 transition-colors"
                data-testid="confirm-delete-button"
              >
                Delete List
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a confirmation modal for clearing all movies from a list.

  ## Examples

      <.clear_confirmation_modal
        show={true}
        list={list}
      />
  """
  attr :show, :boolean, required: true, doc: "Whether to show the modal"
  attr :list, :map, required: true, doc: "The list to be cleared"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def clear_confirmation_modal(assigns) do
    assigns = assign(assigns, :movie_count, length(assigns.list.list_items || []))

    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 overflow-y-auto"
      data-testid="clear-confirmation-modal"
    >
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"></div>

      <!-- Modal -->
      <div class="flex min-h-full items-center justify-center p-4">
        <div class={[
          "relative bg-white rounded-lg shadow-xl max-w-md w-full mx-auto",
          @class
        ]}>
          <div class="p-6">
            <!-- Icon -->
            <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-orange-100 mb-4">
              <.icon name="hero-trash" class="h-6 w-6 text-orange-600" />
            </div>

            <!-- Content -->
            <div class="text-center">
              <h3 class="text-lg font-semibold text-gray-900 mb-2">
                Clear List
              </h3>
              <p class="text-sm text-gray-600 mb-4">
                Are you sure you want to remove all movies from "<strong>{@list.name}</strong>"?
                This will remove {ngettext("1 movie", "all %{count} movies", @movie_count)} but keep the list itself.
                This action cannot be undone.
              </p>
            </div>

            <!-- Actions -->
            <div class="flex items-center justify-end space-x-3 mt-6">
              <button
                type="button"
                phx-click="cancel_clear"
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>

              <button
                type="button"
                phx-click="confirm_clear"
                phx-value-list-id={@list.id}
                class="px-4 py-2 text-sm font-medium text-white bg-orange-600 border border-transparent rounded-md hover:bg-orange-700 transition-colors"
                data-testid="confirm-clear-button"
              >
                Clear List
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a grid of movies within a list with poster images and basic info.

  ## Examples

      <.list_movies_grid movies={movies} />
  """
  attr :movies, :list, required: true, doc: "List of movies with TMDB data"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def list_movies_grid(assigns) do
    ~H"""
    <div
      class={[
        "grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4",
        @class
      ]}
      data-testid="list-movies-grid"
    >
      <%= for movie <- @movies do %>
        <.movie_card movie={movie} />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an individual movie card with poster, title, and remove button.

  ## Examples

      <.movie_card movie={movie} />
  """
  attr :movie, :map, required: true, doc: "Movie data with TMDB information"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def movie_card(assigns) do
    ~H"""
    <div class={["group relative", @class]} data-testid={"movie-card-#{@movie["id"]}"}>
      <!-- Movie Poster -->
      <div class="aspect-[2/3] bg-gray-200 rounded-lg overflow-hidden shadow-md group-hover:shadow-lg transition-shadow">
        <%= if @movie["poster_path"] do %>
          <img
            src={"https://image.tmdb.org/t/p/w500#{@movie["poster_path"]}"}
            alt={@movie["title"]}
            class="w-full h-full object-cover"
            loading="lazy"
          />
        <% else %>
          <div class="w-full h-full flex items-center justify-center bg-gray-300">
            <.icon name="hero-film" class="w-12 h-12 text-gray-500" />
          </div>
        <% end %>

        <!-- Loading Overlay -->
        <%= if Map.get(@movie, "_loading") do %>
          <div class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center">
            <svg
              class="animate-spin h-8 w-8 text-white"
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
          </div>
        <% end %>

        <!-- Remove Button -->
        <div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            phx-click="show_remove_confirmation"
            phx-value-movie-id={@movie["id"]}
            class="p-1 bg-red-600 text-white rounded-full hover:bg-red-700 transition-colors shadow-lg"
            data-testid={"remove-movie-#{@movie["id"]}"}
            title="Remove from list"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <!-- Movie Info -->
      <div class="mt-2">
        <h3 class="text-sm font-medium text-gray-900 truncate" title={@movie["title"]}>
          {@movie["title"]}
        </h3>
        <%= if @movie["release_date"] do %>
          <p class="text-xs text-gray-500">
            {String.slice(@movie["release_date"], 0, 4)}
          </p>
        <% end %>
        <%= if @movie["vote_average"] && @movie["vote_average"] > 0 do %>
          <div class="flex items-center mt-1">
            <.icon name="hero-star" class="w-3 h-3 text-yellow-400 mr-1" />
            <span class="text-xs text-gray-600">
              {Float.round(@movie["vote_average"], 1)}
            </span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders an "Add to List" selector component for choosing which list to add a movie to.

  ## Examples

      <.add_to_list_selector
        show={true}
        lists={user_lists}
        movie_id={550}
      />
  """
  attr :show, :boolean, required: true, doc: "Whether to show the selector"
  attr :lists, :list, required: true, doc: "User's available lists"
  attr :movie_id, :integer, required: true, doc: "TMDB movie ID to add"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def add_to_list_selector(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 overflow-y-auto"
      data-testid="add-to-list-selector"
    >
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"></div>

      <!-- Modal -->
      <div class="flex min-h-full items-center justify-center p-4">
        <div class={[
          "relative bg-white rounded-lg shadow-xl max-w-md w-full mx-auto",
          @class
        ]}>
          <div class="p-6">
            <!-- Header -->
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900">
                Add to List
              </h3>
              <button
                type="button"
                phx-click="cancel_add_to_list"
                class="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <.icon name="hero-x-mark" class="h-5 w-5" />
              </button>
            </div>

            <!-- Lists -->
            <%= if Enum.empty?(@lists) do %>
              <div class="text-center py-8">
                <.icon name="hero-folder-plus" class="mx-auto h-12 w-12 text-gray-400 mb-4" />
                <p class="text-sm text-gray-600 mb-4">
                  You don't have any lists yet.
                </p>
                <button
                  type="button"
                  phx-click="create_first_list"
                  phx-value-movie-id={@movie_id}
                  class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 transition-colors"
                >
                  Create Your First List
                </button>
              </div>
            <% else %>
              <div class="space-y-2 max-h-64 overflow-y-auto">
                <%= for list <- @lists do %>
                  <button
                    type="button"
                    phx-click="add_movie_to_list"
                    phx-value-list-id={list.id}
                    phx-value-movie-id={@movie_id}
                    class="w-full text-left p-3 rounded-lg border border-gray-200 hover:bg-gray-50 hover:border-gray-300 transition-colors"
                    data-testid={"add-to-list-#{list.id}"}
                  >
                    <div class="flex items-center justify-between">
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-gray-900 truncate">
                          {list.name}
                        </p>
                        <%= if list.description && String.trim(list.description) != "" do %>
                          <p class="text-xs text-gray-500 truncate mt-1">
                            {list.description}
                          </p>
                        <% end %>
                      </div>
                      <div class="flex items-center space-x-2 text-xs text-gray-500">
                        <span>{length(list.list_items || [])} movies</span>
                        <%= if list.is_public do %>
                          <.icon name="hero-globe-alt" class="w-3 h-3" />
                        <% else %>
                          <.icon name="hero-lock-closed" class="w-3 h-3" />
                        <% end %>
                      </div>
                    </div>
                  </button>
                <% end %>
              </div>

              <!-- Create New List Option -->
              <div class="mt-4 pt-4 border-t border-gray-100">
                <button
                  type="button"
                  phx-click="create_new_list"
                  phx-value-movie-id={@movie_id}
                  class="w-full flex items-center justify-center p-3 rounded-lg border-2 border-dashed border-gray-300 hover:border-gray-400 hover:bg-gray-50 transition-colors"
                >
                  <.icon name="hero-plus" class="w-4 h-4 mr-2 text-gray-400" />
                  <span class="text-sm font-medium text-gray-600">Create New List</span>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Private helper components

  defp compact_list_stats(assigns) do
    ~H"""
    <div class="p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="flex items-center text-sm text-gray-600">
            <.icon name="hero-film" class="w-4 h-4 mr-1" />
            <span>
              <%= ngettext("1 movie", "%{count} movies", @stats.movie_count) %>
            </span>
          </div>

          <div class="flex items-center text-sm text-gray-600">
            <%= if @stats.is_public do %>
              <.icon name="hero-globe-alt" class="w-4 h-4 mr-1" />
              <span>Public</span>
            <% else %>
              <.icon name="hero-lock-closed" class="w-4 h-4 mr-1" />
              <span>Private</span>
            <% end %>
          </div>
        </div>

        <div class="text-right">
          <div class="text-xs text-gray-500">
            Updated {format_relative_date(DateTime.from_naive!(@stats.updated_at, "Etc/UTC"))}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp full_list_stats(assigns) do
    ~H"""
    <div class="p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">List Statistics</h3>

      <div class="grid grid-cols-2 gap-4">
        <!-- Movie Count -->
        <div class="bg-blue-50 rounded-lg p-4">
          <div class="flex items-center">
            <.icon name="hero-film" class="w-8 h-8 text-blue-600 mr-3" />
            <div>
              <p class="text-2xl font-bold text-blue-900">{@stats.movie_count}</p>
              <p class="text-sm text-blue-600">
                <%= ngettext("Movie", "Movies", @stats.movie_count) %>
              </p>
            </div>
          </div>
        </div>

        <!-- Privacy Status -->
        <div class={[
          "rounded-lg p-4",
          if(@stats.is_public, do: "bg-green-50", else: "bg-gray-50")
        ]}>
          <div class="flex items-center">
            <%= if @stats.is_public do %>
              <.icon name="hero-globe-alt" class="w-8 h-8 text-green-600 mr-3" />
              <div>
                <p class="text-lg font-semibold text-green-900">Public</p>
                <p class="text-sm text-green-600">Visible to others</p>
              </div>
            <% else %>
              <.icon name="hero-lock-closed" class="w-8 h-8 text-gray-600 mr-3" />
              <div>
                <p class="text-lg font-semibold text-gray-900">Private</p>
                <p class="text-sm text-gray-600">Only visible to you</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Dates -->
      <div class="mt-6 pt-4 border-t border-gray-100">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
          <div>
            <span class="text-gray-500">Created:</span>
            <span class="ml-2 text-gray-900">
              {Calendar.strftime(@stats.created_at, "%B %d, %Y")}
            </span>
          </div>
          <div>
            <span class="text-gray-500">Last updated:</span>
            <span class="ml-2 text-gray-900">
              {format_relative_date(DateTime.from_naive!(@stats.updated_at, "Etc/UTC"))}
            </span>
          </div>
        </div>
      </div>
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
          <span class="text-lg font-medium">Loading your lists...</span>
        </div>
      </div>

      <!-- Skeleton grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        <%= for _i <- 1..8 do %>
          <.skeleton_list_card />
        <% end %>
      </div>
    </div>
    """
  end

  defp skeleton_list_card(assigns) do
    ~H"""
    <div
      class="bg-white rounded-lg shadow-md border border-gray-200 overflow-hidden animate-pulse"
      data-testid="skeleton-list-card"
    >
      <!-- Skeleton Header -->
      <div class="p-6 pb-4">
        <div class="flex items-start justify-between mb-3">
          <div class="flex-1">
            <div class="h-5 bg-gray-300 rounded mb-2"></div>
            <div class="h-4 bg-gray-300 rounded w-3/4"></div>
          </div>
          <div class="h-6 w-16 bg-gray-300 rounded-full"></div>
        </div>
        <div class="flex justify-between">
          <div class="h-4 bg-gray-300 rounded w-20"></div>
          <div class="h-4 bg-gray-300 rounded w-24"></div>
        </div>
      </div>

      <!-- Skeleton Actions -->
      <div class="px-6 py-4 bg-gray-50 border-t border-gray-100">
        <div class="flex justify-between">
          <div class="h-4 bg-gray-300 rounded w-16"></div>
          <div class="flex space-x-3">
            <div class="h-4 bg-gray-300 rounded w-8"></div>
            <div class="h-4 bg-gray-300 rounded w-10"></div>
            <div class="h-4 bg-gray-300 rounded w-12"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp empty_lists_state(assigns) do
    ~H"""
    <div class="text-center py-16 px-4" data-testid="empty-lists-state">
      <!-- Empty state icon -->
      <div class="mx-auto w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mb-6">
        <.icon name="hero-folder-plus" class="w-12 h-12 text-gray-400" />
      </div>

      <!-- Empty state content -->
      <h3 class="text-xl font-semibold text-gray-900 mb-2">No movie lists yet</h3>
      <p class="text-gray-600 mb-6 max-w-md mx-auto">
        Create your first movie list to start organizing your favorite films.
        You can make lists for different genres, moods, or any way you like to categorize movies.
      </p>

      <!-- Create first list button -->
      <button
        phx-click="show_create_form"
        class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
        data-testid="create-first-list-button"
      >
        Create Your First List
      </button>
    </div>
    """
  end

  defp error_state(assigns) do
    ~H"""
    <div class="text-center py-16 px-4" data-testid="error-state">
      <!-- Error icon -->
      <div class="mx-auto w-24 h-24 bg-red-100 rounded-full flex items-center justify-center mb-6">
        <.icon name="hero-exclamation-triangle" class="w-12 h-12 text-red-500" />
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

  # Helper functions

  defp format_relative_date(%DateTime{} = datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :day) do
      0 -> "today"
      1 -> "yesterday"
      days when days < 7 -> "#{days} days ago"
      days when days < 30 -> "#{div(days, 7)} weeks ago"
      days when days < 365 -> "#{div(days, 30)} months ago"
      _ -> Calendar.strftime(datetime, "%B %Y")
    end
  end

  defp error_message(:timeout), do: "The request timed out. Please check your connection and try again."
  defp error_message(:unauthorized), do: "You don't have permission to access these lists."
  defp error_message(:network_error), do: "Network connection error. Please check your internet connection."
  defp error_message(error) when is_binary(error), do: error
  defp error_message(_), do: "An unexpected error occurred. Please try again."
end
