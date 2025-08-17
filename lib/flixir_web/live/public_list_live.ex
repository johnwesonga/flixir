defmodule FlixirWeb.PublicListLive do
  use FlixirWeb, :live_view

  alias Flixir.Lists

  @impl true
  def mount(%{"tmdb_list_id" => tmdb_list_id}, _session, socket) do
    case Integer.parse(tmdb_list_id) do
      {list_id, ""} ->
        case Lists.get_public_list(list_id) do
          {:ok, list} ->
            {:ok,
             socket
             |> assign(:list, list)
             |> assign(:movies, list.movies || [])
             |> assign(:loading, false)
             |> assign(:error, nil)
             |> assign(:page_title, "#{list.name} - Public List")}

          {:error, :not_found} ->
            {:ok,
             socket
             |> assign(:list, nil)
             |> assign(:movies, [])
             |> assign(:loading, false)
             |> assign(:error, "List not found")
             |> assign(:page_title, "List Not Found")}

          {:error, :private_list} ->
            {:ok,
             socket
             |> assign(:list, nil)
             |> assign(:movies, [])
             |> assign(:loading, false)
             |> assign(:error, "This list is private and cannot be viewed publicly")
             |> assign(:page_title, "Private List")}

          {:error, reason} ->
            {:ok,
             socket
             |> assign(:list, nil)
             |> assign(:movies, [])
             |> assign(:loading, false)
             |> assign(:error, "Unable to load list: #{inspect(reason)}")
             |> assign(:page_title, "Error Loading List")}
        end

      :error ->
        {:ok,
         socket
         |> assign(:list, nil)
         |> assign(:movies, [])
         |> assign(:loading, false)
         |> assign(:error, "Invalid list ID format")
         |> assign(:page_title, "Invalid List ID")}
    end
  end

  @impl true
  def handle_event("refresh_list", _params, socket) do
    case socket.assigns.list do
      nil ->
        {:noreply, socket}

      list ->
        case Lists.get_public_list(list.tmdb_list_id) do
          {:ok, updated_list} ->
            {:noreply,
             socket
             |> assign(:list, updated_list)
             |> assign(:movies, updated_list.movies || [])
             |> assign(:error, nil)
             |> put_flash(:info, "List refreshed successfully")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:error, "Failed to refresh list: #{inspect(reason)}")
             |> put_flash(:error, "Failed to refresh list")}
        end
    end
  end

  @impl true
  def handle_event("view_on_tmdb", _params, socket) do
    case socket.assigns.list do
      nil ->
        {:noreply, socket}

      list ->
        tmdb_url = "https://www.themoviedb.org/list/#{list.tmdb_list_id}"
        {:noreply, redirect(socket, external: tmdb_url)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <%= if @error do %>
        <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          <strong class="font-bold">Error:</strong>
          <span class="block sm:inline"><%= @error %></span>
        </div>
        <div class="text-center">
          <.link navigate={~p"/"} class="text-blue-600 hover:text-blue-800 underline">
            Return to Home
          </.link>
        </div>
      <% else %>
        <%= if @list do %>
          <div class="bg-white shadow-lg rounded-lg overflow-hidden">
            <!-- List Header -->
            <div class="bg-gradient-to-r from-blue-600 to-purple-600 text-white p-6">
              <div class="flex justify-between items-start">
                <div>
                  <h1 class="text-3xl font-bold mb-2"><%= @list.name %></h1>
                  <%= if @list.description && @list.description != "" do %>
                    <p class="text-blue-100 text-lg"><%= @list.description %></p>
                  <% end %>
                  <div class="flex items-center mt-4 space-x-4 text-sm">
                    <span class="bg-white/20 px-3 py-1 rounded-full">
                      <%= @list.item_count || length(@movies) %> movies
                    </span>
                    <span class="bg-white/20 px-3 py-1 rounded-full">
                      Public List
                    </span>
                    <%= if @list.created_at do %>
                      <span class="bg-white/20 px-3 py-1 rounded-full">
                        Created <%= Calendar.strftime(@list.created_at, "%B %d, %Y") %>
                      </span>
                    <% end %>
                  </div>
                </div>
                <div class="flex space-x-2">
                  <button
                    phx-click="refresh_list"
                    class="bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                  </button>
                  <button
                    phx-click="view_on_tmdb"
                    class="bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors"
                  >
                    View on TMDB
                  </button>
                </div>
              </div>
            </div>

            <!-- Movies Grid -->
            <div class="p-6">
              <%= if length(@movies) > 0 do %>
                <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
                  <%= for movie <- @movies do %>
                    <div class="bg-gray-50 rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow">
                      <.link navigate={~p"/media/movie/#{movie.tmdb_movie_id}"}>
                        <%= if movie.poster_path do %>
                          <img
                            src={"https://image.tmdb.org/t/p/w300#{movie.poster_path}"}
                            alt={movie.title}
                            class="w-full h-48 object-cover"
                          />
                        <% else %>
                          <div class="w-full h-48 bg-gray-200 flex items-center justify-center">
                            <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 011 1v1a1 1 0 01-1 1H3a1 1 0 01-1-1V5a1 1 0 011-1h4zM3 8v11a2 2 0 002 2h14a2 2 0 002-2V8H3z" />
                            </svg>
                          </div>
                        <% end %>
                        <div class="p-3">
                          <h3 class="font-semibold text-sm text-gray-900 line-clamp-2"><%= movie.title %></h3>
                          <%= if movie.release_date do %>
                            <p class="text-xs text-gray-500 mt-1">
                              <%= String.slice(movie.release_date, 0, 4) %>
                            </p>
                          <% end %>
                          <%= if movie.vote_average do %>
                            <div class="flex items-center mt-1">
                              <svg class="w-3 h-3 text-yellow-400 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                              </svg>
                              <span class="text-xs text-gray-600"><%= Float.round(movie.vote_average, 1) %></span>
                            </div>
                          <% end %>
                        </div>
                      </.link>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="text-center py-12">
                  <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                  </svg>
                  <h3 class="text-lg font-medium text-gray-900 mb-2">No movies in this list</h3>
                  <p class="text-gray-500">This list doesn't contain any movies yet.</p>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
