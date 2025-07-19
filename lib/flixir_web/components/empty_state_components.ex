defmodule FlixirWeb.Components.EmptyStateComponents do
  @moduledoc """
  Empty state components for when no reviews or data are available.
  """

  use Phoenix.Component
  import FlixirWeb.CoreComponents

  @doc """
  Renders an empty state when no reviews are available.
  """
  attr :title, :string, default: "No reviews yet"
  attr :description, :string, default: "Be the first to share your thoughts about this content."
  attr :icon, :string, default: "hero-chat-bubble-left-ellipsis"
  attr :action_text, :string, default: nil
  attr :action_href, :string, default: nil
  attr :class, :string, default: ""

  def no_reviews_empty_state(assigns) do
    ~H"""
    <div class={["text-center py-12", @class]}>
      <div class="mx-auto w-24 h-24 text-gray-400 mb-4">
        <.icon name={@icon} class="w-full h-full" />
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2"><%= @title %></h3>
      <p class="text-gray-500 mb-6 max-w-md mx-auto"><%= @description %></p>
      <div :if={@action_text && @action_href}>
        <.link
          href={@action_href}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <%= @action_text %>
        </.link>
      </div>
    </div>
    """
  end

  @doc """
  Renders an empty state when no filtered results are found.
  """
  attr :filters_applied, :boolean, default: true
  attr :clear_filters_event, :string, default: "clear-filters"
  attr :class, :string, default: ""

  def no_filtered_results_empty_state(assigns) do
    ~H"""
    <div class={["text-center py-12", @class]}>
      <div class="mx-auto w-24 h-24 text-gray-400 mb-4">
        <.icon name="hero-funnel" class="w-full h-full" />
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2">No reviews match your filters</h3>
      <p class="text-gray-500 mb-6 max-w-md mx-auto">
        Try adjusting your search criteria or clearing the filters to see more results.
      </p>
      <div :if={@filters_applied}>
        <button
          type="button"
          phx-click={@clear_filters_event}
          class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <.icon name="hero-x-mark" class="w-4 h-4 mr-2" />
          Clear filters
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders an empty state for rating statistics when no ratings are available.
  """
  attr :class, :string, default: ""

  def no_ratings_empty_state(assigns) do
    ~H"""
    <div class={["text-center py-8", @class]}>
      <div class="mx-auto w-16 h-16 text-gray-400 mb-3">
        <.icon name="hero-star" class="w-full h-full" />
      </div>
      <h4 class="text-base font-medium text-gray-900 mb-1">Not yet rated</h4>
      <p class="text-sm text-gray-500">No ratings available for this content.</p>
    </div>
    """
  end

  @doc """
  Renders a generic error state with retry option.
  """
  attr :title, :string, default: "Something went wrong"
  attr :description, :string, required: true
  attr :retry_event, :string, default: nil
  attr :retry_text, :string, default: "Try again"
  attr :icon, :string, default: "hero-exclamation-triangle"
  attr :class, :string, default: ""

  def error_state(assigns) do
    ~H"""
    <div class={["text-center py-12", @class]}>
      <div class="mx-auto w-24 h-24 text-red-400 mb-4">
        <.icon name={@icon} class="w-full h-full" />
      </div>
      <h3 class="text-lg font-medium text-gray-900 mb-2"><%= @title %></h3>
      <p class="text-gray-500 mb-6 max-w-md mx-auto"><%= @description %></p>
      <div :if={@retry_event}>
        <button
          type="button"
          phx-click={@retry_event}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
        >
          <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" />
          <%= @retry_text %>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a network error state with specific messaging.
  """
  attr :retry_event, :string, default: "retry-load"
  attr :class, :string, default: ""

  def network_error_state(assigns) do
    ~H"""
    <.error_state
      title="Connection problem"
      description="Unable to load reviews due to connection issues. Please check your internet connection and try again."
      retry_event={@retry_event}
      icon="hero-wifi"
      class={@class}
    />
    """
  end

  @doc """
  Renders a service unavailable error state.
  """
  attr :retry_event, :string, default: "retry-load"
  attr :class, :string, default: ""

  def service_error_state(assigns) do
    ~H"""
    <.error_state
      title="Service temporarily unavailable"
      description="The review service is currently unavailable. Please try again in a few moments."
      retry_event={@retry_event}
      icon="hero-server"
      class={@class}
    />
    """
  end

  @doc """
  Renders a rate limit error state.
  """
  attr :class, :string, default: ""

  def rate_limit_error_state(assigns) do
    ~H"""
    <.error_state
      title="Too many requests"
      description="Please wait a moment before trying again."
      icon="hero-clock"
      class={@class}
    />
    """
  end

  @doc """
  Renders a compact empty state for inline use.
  """
  attr :message, :string, default: "No data available"
  attr :icon, :string, default: "hero-document"
  attr :class, :string, default: ""

  def compact_empty_state(assigns) do
    ~H"""
    <div class={["flex items-center justify-center py-6 text-gray-500", @class]}>
      <.icon name={@icon} class="w-5 h-5 mr-2" />
      <span class="text-sm"><%= @message %></span>
    </div>
    """
  end
end
