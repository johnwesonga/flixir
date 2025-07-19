defmodule FlixirWeb.Components.LoadingComponents do
  @moduledoc """
  Loading indicators and skeleton screens for reviews.
  """

  use Phoenix.Component
  import FlixirWeb.CoreComponents

  @doc """
  Renders a loading spinner with optional message.
  """
  attr :message, :string, default: "Loading..."
  attr :size, :string, default: "md", values: ["sm", "md", "lg"]
  attr :class, :string, default: ""

  def loading_spinner(assigns) do
    ~H"""
    <div class={["flex items-center justify-center space-x-2", @class]}>
      <div class={[
        "animate-spin rounded-full border-2 border-gray-300 border-t-blue-600",
        spinner_size_class(@size)
      ]}>
      </div>
      <span class={["text-gray-600", text_size_class(@size)]}><%= @message %></span>
    </div>
    """
  end

  @doc """
  Renders skeleton placeholders for review cards while loading.
  """
  attr :count, :integer, default: 3
  attr :class, :string, default: ""

  def review_skeleton(assigns) do
    ~H"""
    <div class={["space-y-4", @class]}>
      <div :for={_ <- 1..@count} class="animate-pulse">
        <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <!-- Author and rating skeleton -->
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 bg-gray-300 rounded-full"></div>
              <div class="space-y-2">
                <div class="h-4 bg-gray-300 rounded w-24"></div>
                <div class="h-3 bg-gray-300 rounded w-16"></div>
              </div>
            </div>
            <div class="flex space-x-1">
              <div :for={_ <- 1..5} class="w-4 h-4 bg-gray-300 rounded"></div>
            </div>
          </div>

          <!-- Content skeleton -->
          <div class="space-y-3">
            <div class="h-4 bg-gray-300 rounded w-full"></div>
            <div class="h-4 bg-gray-300 rounded w-5/6"></div>
            <div class="h-4 bg-gray-300 rounded w-4/6"></div>
            <div class="h-4 bg-gray-300 rounded w-3/6"></div>
          </div>

          <!-- Date skeleton -->
          <div class="mt-4 pt-4 border-t border-gray-100">
            <div class="h-3 bg-gray-300 rounded w-20"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders skeleton for rating statistics.
  """
  attr :class, :string, default: ""

  def rating_stats_skeleton(assigns) do
    ~H"""
    <div class={["animate-pulse", @class]}>
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <!-- Average rating skeleton -->
        <div class="flex items-center space-x-4 mb-6">
          <div class="w-16 h-16 bg-gray-300 rounded-full"></div>
          <div class="space-y-2">
            <div class="h-6 bg-gray-300 rounded w-20"></div>
            <div class="h-4 bg-gray-300 rounded w-32"></div>
          </div>
        </div>

        <!-- Rating distribution skeleton -->
        <div class="space-y-3">
          <div class="h-4 bg-gray-300 rounded w-24 mb-4"></div>
          <div :for={_ <- 1..5} class="flex items-center space-x-3">
            <div class="h-3 bg-gray-300 rounded w-8"></div>
            <div class="flex-1 h-2 bg-gray-300 rounded"></div>
            <div class="h-3 bg-gray-300 rounded w-8"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a loading overlay for partial updates.
  """
  attr :show, :boolean, default: false
  attr :message, :string, default: "Loading..."
  slot :inner_block, required: true

  def loading_overlay(assigns) do
    ~H"""
    <div class="relative">
      <%= render_slot(@inner_block) %>
      <div :if={@show} class="absolute inset-0 bg-white bg-opacity-75 flex items-center justify-center z-10">
        <.loading_spinner message={@message} />
      </div>
    </div>
    """
  end

  @doc """
  Renders a skeleton for filter controls.
  """
  attr :class, :string, default: ""

  def filter_skeleton(assigns) do
    ~H"""
    <div class={["animate-pulse flex items-center space-x-4", @class]}>
      <div class="h-10 bg-gray-300 rounded w-32"></div>
      <div class="h-10 bg-gray-300 rounded w-24"></div>
      <div class="h-10 bg-gray-300 rounded w-28"></div>
    </div>
    """
  end

  @doc """
  Renders a loading state for pagination.
  """
  attr :class, :string, default: ""

  def pagination_skeleton(assigns) do
    ~H"""
    <div class={["animate-pulse flex items-center justify-between", @class]}>
      <div class="h-4 bg-gray-300 rounded w-32"></div>
      <div class="flex space-x-2">
        <div class="h-8 w-8 bg-gray-300 rounded"></div>
        <div class="h-8 w-8 bg-gray-300 rounded"></div>
        <div class="h-8 w-8 bg-gray-300 rounded"></div>
      </div>
    </div>
    """
  end

  # Private helper functions

  defp spinner_size_class("sm"), do: "h-4 w-4"
  defp spinner_size_class("md"), do: "h-6 w-6"
  defp spinner_size_class("lg"), do: "h-8 w-8"

  defp text_size_class("sm"), do: "text-sm"
  defp text_size_class("md"), do: "text-base"
  defp text_size_class("lg"), do: "text-lg"
end
