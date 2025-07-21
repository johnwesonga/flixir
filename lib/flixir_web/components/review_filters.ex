defmodule FlixirWeb.ReviewFilters do
  @moduledoc """
  Review filtering and sorting components for interactive review management.

  This module provides components for filtering reviews by rating, author, and content,
  as well as sorting options with real-time updates and clear visual indicators
  for active filters.
  """

  use Phoenix.Component
  use Gettext, backend: FlixirWeb.Gettext

  import FlixirWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the main review filters component with sort and filter controls.

  ## Examples

      <.review_filters
        filters={%{sort_by: :date, sort_order: :desc}}
        on_filter_change="update_filters"
      />
  """
  attr :filters, :map, required: true, doc: "Current filter state"
  attr :on_filter_change, :string, required: true, doc: "Event name for filter changes"
  attr :total_reviews, :integer, default: 0, doc: "Total number of reviews"
  attr :filtered_count, :integer, default: 0, doc: "Number of reviews after filtering"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :id, :string, default: "review-filters", doc: "Component ID"

  def review_filters(assigns) do
    assigns = assign(assigns, :active_filters_count, count_active_filters(assigns.filters))
    assigns = assign(assigns, :has_active_filters, assigns.active_filters_count > 0)

    ~H"""
    <div
      id={@id}
      class={[
        "bg-white border border-gray-200 rounded-lg p-4 space-y-4",
        @class
      ]}
      data-testid="review-filters"
    >
      <!-- Filter Header -->
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <.icon name="hero-funnel" class="w-5 h-5 text-gray-500" />
          <h3 class="font-medium text-gray-900">Filter & Sort Reviews</h3>
          <%= if @has_active_filters do %>
            <span class="bg-blue-100 text-blue-800 text-xs font-medium px-2 py-1 rounded-full">
              {@active_filters_count} active
            </span>
          <% end %>
        </div>

        <%= if @has_active_filters do %>
          <button
            type="button"
            phx-click={@on_filter_change}
            phx-value-action="clear_all"
            class="text-sm text-gray-500 hover:text-gray-700 transition-colors duration-200"
            data-testid="clear-all-filters"
          >
            Clear all
          </button>
        <% end %>
      </div>

    <!-- Results Summary -->
      <%= if @total_reviews > 0 do %>
        <div class="text-sm text-gray-600">
          <%= if @filtered_count != @total_reviews do %>
            Showing {@filtered_count} of {@total_reviews} reviews
          <% else %>
            Showing all {@total_reviews} reviews
          <% end %>
        </div>
      <% end %>

    <!-- Filter Controls -->
      <form phx-change={@on_filter_change}>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <!-- Sort By -->
          <.sort_control
            current_sort={Map.get(@filters, :sort_by, :date)}
            current_order={Map.get(@filters, :sort_order, :desc)}
            on_change={@on_filter_change}
          />

    <!-- Rating Filter -->
          <.rating_filter
            current_filter={Map.get(@filters, :filter_by_rating)}
            on_change={@on_filter_change}
          />

    <!-- Author Filter -->
          <.author_filter
            current_filter={Map.get(@filters, :author_filter)}
            on_change={@on_filter_change}
          />

    <!-- Content Filter -->
          <.content_filter
            current_filter={Map.get(@filters, :content_filter)}
            on_change={@on_filter_change}
          />
        </div>
      </form>

    <!-- Active Filters Display -->
      <%= if @has_active_filters do %>
        <.active_filters_display filters={@filters} on_remove={@on_filter_change} />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders the sort control dropdown.
  """
  attr :current_sort, :atom, required: true
  attr :current_order, :atom, required: true
  attr :on_change, :string, required: true

  def sort_control(assigns) do
    ~H"""
    <div class="space-y-2">
      <label class="block text-sm font-medium text-gray-700">Sort by</label>
      <div class="flex gap-2">
        <select
          name="sort_by"
          class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
          data-testid="sort-by-select"
        >
          <option value="date" selected={@current_sort == :date}>Date</option>
          <option value="rating" selected={@current_sort == :rating}>Rating</option>
          <option value="author" selected={@current_sort == :author}>Author</option>
        </select>

        <button
          type="button"
          phx-click={@on_change}
          phx-value-action="toggle_sort_order"
          class={[
            "px-3 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium transition-colors duration-200",
            if(@current_order == :desc,
              do: "bg-gray-100 text-gray-700",
              else: "bg-white text-gray-500 hover:bg-gray-50"
            )
          ]}
          title={if @current_order == :desc, do: "Sort descending", else: "Sort ascending"}
          data-testid="sort-order-toggle"
        >
          <%= if @current_order == :desc do %>
            <.icon name="hero-arrow-down" class="w-4 h-4" />
          <% else %>
            <.icon name="hero-arrow-up" class="w-4 h-4" />
          <% end %>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders the rating filter control.
  """
  attr :current_filter, :any, default: nil
  attr :on_change, :string, required: true

  def rating_filter(assigns) do
    ~H"""
    <div class="space-y-2">
      <label class="block text-sm font-medium text-gray-700">Rating</label>
      <select
        name="filter_by_rating"
        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
        data-testid="rating-filter-select"
      >
        <option value="" selected={is_nil(@current_filter)}>All ratings</option>
        <option value="positive" selected={@current_filter == :positive}>Positive (6+ stars)</option>
        <option value="negative" selected={@current_filter == :negative}>
          Negative (&lt; 6 stars)
        </option>
        <option value="high" selected={@current_filter == {8, 10}}>High (8-10 stars)</option>
        <option value="medium" selected={@current_filter == {5, 7}}>Medium (5-7 stars)</option>
        <option value="low" selected={@current_filter == {1, 4}}>Low (1-4 stars)</option>
      </select>
    </div>
    """
  end

  @doc """
  Renders the author filter input.
  """
  attr :current_filter, :string, default: nil
  attr :on_change, :string, required: true

  def author_filter(assigns) do
    ~H"""
    <div class="space-y-2">
      <label class="block text-sm font-medium text-gray-700">Author</label>
      <div class="relative">
        <input
          type="text"
          name="author_filter"
          value={@current_filter || ""}
          placeholder="Filter by author name..."
          phx-debounce="300"
          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm pr-8"
          data-testid="author-filter-input"
        />
        <%= if @current_filter && String.trim(@current_filter) != "" do %>
          <button
            type="button"
            phx-click={@on_change}
            phx-value-action="clear_author"
            class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
            data-testid="clear-author-filter"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders the content filter input.
  """
  attr :current_filter, :string, default: nil
  attr :on_change, :string, required: true

  def content_filter(assigns) do
    ~H"""
    <div class="space-y-2">
      <label class="block text-sm font-medium text-gray-700">Content</label>
      <div class="relative">
        <input
          type="text"
          name="content_filter"
          value={@current_filter || ""}
          placeholder="Search review content..."
          phx-debounce="300"
          class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm pr-8"
          data-testid="content-filter-input"
        />
        <%= if @current_filter && String.trim(@current_filter) != "" do %>
          <button
            type="button"
            phx-click={@on_change}
            phx-value-action="clear_content"
            class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
            data-testid="clear-content-filter"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders active filters as removable tags.
  """
  attr :filters, :map, required: true
  attr :on_remove, :string, required: true

  def active_filters_display(assigns) do
    assigns = assign(assigns, :active_filter_tags, build_active_filter_tags(assigns.filters))

    ~H"""
    <div class="space-y-2">
      <h4 class="text-sm font-medium text-gray-700">Active Filters</h4>
      <div class="flex flex-wrap gap-2">
        <%= for {label, action, value} <- @active_filter_tags do %>
          <span class="inline-flex items-center gap-1 bg-blue-100 text-blue-800 text-xs font-medium px-2 py-1 rounded-full">
            {label}
            <button
              type="button"
              phx-click={@on_remove}
              phx-value-action={action}
              phx-value-value={value}
              class="text-blue-600 hover:text-blue-800 transition-colors duration-200"
              data-testid={"remove-filter-#{action}"}
            >
              <.icon name="hero-x-mark" class="w-3 h-3" />
            </button>
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions

  def count_active_filters(filters) do
    count = 0

    # Count sort changes as active filters
    count = if Map.get(filters, :sort_by) != :date, do: count + 1, else: count
    count = if Map.get(filters, :sort_order) != :desc, do: count + 1, else: count

    # Count actual filters
    count = if Map.get(filters, :filter_by_rating), do: count + 1, else: count
    count = if filter_present?(Map.get(filters, :author_filter)), do: count + 1, else: count
    count = if filter_present?(Map.get(filters, :content_filter)), do: count + 1, else: count

    count
  end

  defp filter_present?(nil), do: false
  defp filter_present?(""), do: false
  defp filter_present?(value) when is_binary(value), do: String.trim(value) != ""
  defp filter_present?(_), do: true

  defp build_active_filter_tags(filters) do
    tags = []

    # Sort filter (if not default)
    tags =
      if Map.get(filters, :sort_by) != :date or Map.get(filters, :sort_order) != :desc do
        sort_by = Map.get(filters, :sort_by, :date)
        sort_order = Map.get(filters, :sort_order, :desc)
        sort_label = format_sort_label(sort_by)
        order_symbol = if sort_order == :desc, do: "↓", else: "↑"
        [{"Sort: #{sort_label} #{order_symbol}", "clear_sort", ""} | tags]
      else
        tags
      end

    # Rating filter
    tags =
      if rating_filter = Map.get(filters, :filter_by_rating) do
        label = format_rating_filter_label(rating_filter)
        [{"Rating: #{label}", "clear_rating", ""} | tags]
      else
        tags
      end

    # Author filter
    tags =
      case Map.get(filters, :author_filter) do
        author_filter when is_binary(author_filter) ->
          if filter_present?(author_filter) do
            [{"Author: #{String.slice(author_filter, 0, 20)}", "clear_author", ""} | tags]
          else
            tags
          end

        _ ->
          tags
      end

    # Content filter
    tags =
      case Map.get(filters, :content_filter) do
        content_filter when is_binary(content_filter) ->
          if filter_present?(content_filter) do
            [{"Content: #{String.slice(content_filter, 0, 20)}", "clear_content", ""} | tags]
          else
            tags
          end

        _ ->
          tags
      end

    Enum.reverse(tags)
  end

  defp format_sort_label(:date), do: "Date"
  defp format_sort_label(:rating), do: "Rating"
  defp format_sort_label(:author), do: "Author"
  defp format_sort_label(_), do: "Unknown"

  defp format_rating_filter_label(:positive), do: "Positive"
  defp format_rating_filter_label(:negative), do: "Negative"
  defp format_rating_filter_label({8, 10}), do: "High (8-10)"
  defp format_rating_filter_label({5, 7}), do: "Medium (5-7)"
  defp format_rating_filter_label({1, 4}), do: "Low (1-4)"
  defp format_rating_filter_label(_), do: "Custom"
end
