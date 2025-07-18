defmodule FlixirWeb.ReviewComponents do
  @moduledoc """
  Review-related UI components for displaying movie and TV show reviews.

  This module contains reusable components for displaying individual reviews,
  rating statistics, and interactive elements like expandable content and
  spoiler warnings.
  """

  use Phoenix.Component
  use Gettext, backend: FlixirWeb.Gettext

  alias Phoenix.LiveView.JS
  import FlixirWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a review card component with expandable content and spoiler handling.

  ## Examples

      <.review_card review={review} />
      <.review_card review={review} expanded={true} />
  """
  attr :review, :map, required: true, doc: "The review data"
  attr :expanded, :boolean, default: false, doc: "Whether the review content is expanded"
  attr :show_spoilers, :boolean, default: false, doc: "Whether spoiler content is revealed"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :id, :string, default: nil, doc: "Optional ID for the review card"

  def review_card(assigns) do
    assigns = assign_new(assigns, :id, fn -> "review-#{assigns.review.id}" end)
    assigns = assign(assigns, :truncated_content, truncate_content(assigns.review.content, 300))
    assigns = assign(assigns, :has_spoilers, has_spoilers?(assigns.review.content))
    assigns = assign(assigns, :needs_expansion, String.length(assigns.review.content) > 300)

    ~H"""
    <div
      id={@id}
      class={[
        "bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow duration-200",
        @class
      ]}
      data-testid="review-card"
    >
      <!-- Review Header -->
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <div class="flex items-center gap-3 mb-2">
            <!-- Author Avatar -->
            <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center text-white font-semibold text-sm">
              <%= String.first(@review.author) |> String.upcase() %>
            </div>

            <!-- Author Info -->
            <div>
              <h4 class="font-semibold text-gray-900 text-sm">
                <%= @review.author %>
              </h4>
              <%= if @review.created_at do %>
                <time class="text-xs text-gray-500" datetime={DateTime.to_iso8601(@review.created_at)}>
                  <%= format_review_date(@review.created_at) %>
                </time>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Rating -->
        <%= if @review.rating do %>
          <div class="flex items-center gap-1 bg-yellow-50 px-2 py-1 rounded-full">
            <.icon name="hero-star-solid" class="w-4 h-4 text-yellow-400" />
            <span class="text-sm font-medium text-yellow-700">
              <%= Float.round(@review.rating, 1) %>
            </span>
          </div>
        <% end %>
      </div>

      <!-- Review Content -->
      <div class="prose prose-sm max-w-none">
        <%= if @has_spoilers and not @show_spoilers do %>
          <.spoiler_warning review_id={@review.id} />
        <% else %>
          <%= if @needs_expansion and not @expanded do %>
            <div class="space-y-3">
              <p class="text-gray-700 leading-relaxed">
                <%= @truncated_content %>
              </p>
              <button
                type="button"
                phx-click={JS.push("expand_review", value: %{review_id: @review.id})}
                class="text-blue-600 hover:text-blue-800 text-sm font-medium transition-colors duration-200"
                data-testid="read-more-button"
              >
                Read more
              </button>
            </div>
          <% else %>
            <div class="space-y-3">
              <p class="text-gray-700 leading-relaxed whitespace-pre-wrap">
                <%= @review.content %>
              </p>
              <%= if @needs_expansion and @expanded do %>
                <button
                  type="button"
                  phx-click={JS.push("collapse_review", value: %{review_id: @review.id})}
                  class="text-blue-600 hover:text-blue-800 text-sm font-medium transition-colors duration-200"
                  data-testid="show-less-button"
                >
                  Show less
                </button>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>

      <!-- Review Footer -->
      <%= if @review.url do %>
        <div class="mt-4 pt-4 border-t border-gray-100">
          <a
            href={@review.url}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 transition-colors duration-200"
          >
            View original review
            <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
          </a>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a spoiler warning overlay for review content.

  ## Examples

      <.spoiler_warning review_id="123" />
  """
  attr :review_id, :string, required: true, doc: "The review ID for targeting spoiler reveal"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def spoiler_warning(assigns) do
    ~H"""
    <div class={["bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg p-6 text-center", @class]}>
      <div class="flex flex-col items-center gap-3">
        <.icon name="hero-exclamation-triangle" class="w-8 h-8 text-amber-500" />
        <div>
          <h4 class="font-medium text-gray-900 mb-1">Spoiler Warning</h4>
          <p class="text-sm text-gray-600 mb-4">
            This review may contain spoilers about the plot or ending.
          </p>
          <button
            type="button"
            phx-click={JS.push("reveal_spoilers", value: %{review_id: @review_id})}
            class="bg-amber-100 hover:bg-amber-200 text-amber-800 px-4 py-2 rounded-lg text-sm font-medium transition-colors duration-200"
            data-testid="reveal-spoilers-button"
          >
            Show spoilers anyway
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders aggregated rating statistics with visual breakdown.

  ## Examples

      <.rating_display stats={rating_stats} />
      <.rating_display stats={rating_stats} compact={true} />
  """
  attr :stats, :map, required: true, doc: "The rating statistics data"
  attr :compact, :boolean, default: false, doc: "Whether to show compact version"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def rating_display(assigns) do
    assigns = assign(assigns, :rating_percentages, rating_percentages(assigns.stats))
    assigns = assign(assigns, :formatted_rating, format_average_rating(assigns.stats.average_rating))

    ~H"""
    <div class={["bg-white rounded-lg border border-gray-200", @class]} data-testid="rating-display">
      <%= if @compact do %>
        <.compact_rating_display stats={@stats} formatted_rating={@formatted_rating} />
      <% else %>
        <.full_rating_display
          stats={@stats}
          formatted_rating={@formatted_rating}
          rating_percentages={@rating_percentages}
        />
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a compact version of rating statistics.
  """
  attr :stats, :map, required: true
  attr :formatted_rating, :string, required: true

  def compact_rating_display(assigns) do
    ~H"""
    <div class="p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <%= if @stats.average_rating do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-star-solid" class="w-5 h-5 text-yellow-400" />
              <span class="text-lg font-semibold text-gray-900">
                <%= @formatted_rating %>
              </span>
              <span class="text-sm text-gray-500">/10</span>
            </div>
          <% else %>
            <div class="flex items-center gap-1">
              <.icon name="hero-star" class="w-5 h-5 text-gray-300" />
              <span class="text-sm text-gray-500">Not yet rated</span>
            </div>
          <% end %>
        </div>

        <div class="text-right">
          <div class="text-sm text-gray-600">
            <%= ngettext("1 review", "%{count} reviews", @stats.total_reviews) %>
          </div>
          <%= if @stats.source != "merged" do %>
            <div class="text-xs text-gray-400 uppercase tracking-wide">
              <%= @stats.source %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the full rating display with breakdown.
  """
  attr :stats, :map, required: true
  attr :formatted_rating, :string, required: true
  attr :rating_percentages, :map, required: true

  def full_rating_display(assigns) do
    ~H"""
    <div class="p-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">User Reviews</h3>
        <%= if @stats.source != "merged" do %>
          <div class="text-xs text-gray-400 uppercase tracking-wide bg-gray-100 px-2 py-1 rounded">
            <%= @stats.source %>
          </div>
        <% end %>
      </div>

      <!-- Main Rating -->
      <div class="text-center mb-6">
        <%= if @stats.average_rating do %>
          <div class="flex items-center justify-center gap-2 mb-2">
            <.icon name="hero-star-solid" class="w-8 h-8 text-yellow-400" />
            <span class="text-4xl font-bold text-gray-900">
              <%= @formatted_rating %>
            </span>
            <span class="text-xl text-gray-500">/10</span>
          </div>
          <p class="text-gray-600">
            Based on <%= ngettext("1 review", "%{count} reviews", @stats.total_reviews) %>
          </p>
        <% else %>
          <div class="flex items-center justify-center gap-2 mb-2">
            <.icon name="hero-star" class="w-8 h-8 text-gray-300" />
            <span class="text-2xl font-medium text-gray-500">Not yet rated</span>
          </div>
          <p class="text-gray-500">
            <%= if @stats.total_reviews > 0 do %>
              <%= ngettext("1 review", "%{count} reviews", @stats.total_reviews) %> without ratings
            <% else %>
              No reviews available
            <% end %>
          </p>
        <% end %>
      </div>

      <%= if not is_nil(@stats.average_rating) and @stats.total_reviews > 0 and map_size(@rating_percentages) > 0 do %>
        <!-- Rating Breakdown -->
        <div class="space-y-2">
          <h4 class="text-sm font-medium text-gray-700 mb-3">Rating Breakdown</h4>
          <%= for rating <- ["10", "9", "8", "7", "6", "5", "4", "3", "2", "1"] do %>
            <% percentage = Map.get(@rating_percentages, rating, 0) %>
            <%= if percentage > 0 do %>
              <.rating_bar rating={rating} percentage={percentage} />
            <% end %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a single rating bar in the breakdown.
  """
  attr :rating, :string, required: true
  attr :percentage, :float, required: true

  def rating_bar(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <div class="flex items-center gap-1 w-8">
        <span class="text-sm text-gray-600"><%= @rating %></span>
        <.icon name="hero-star-solid" class="w-3 h-3 text-yellow-400" />
      </div>
      <div class="flex-1 bg-gray-200 rounded-full h-2">
        <div
          class="bg-yellow-400 h-2 rounded-full transition-all duration-300"
          style={"width: #{@percentage}%"}
        ></div>
      </div>
      <span class="text-xs text-gray-500 w-10 text-right">
        <%= Float.round(@percentage, 1) %>%
      </span>
    </div>
    """
  end

  # Helper functions (public for testing)

  def truncate_content(content, max_length) when is_binary(content) do
    if String.length(content) <= max_length do
      content
    else
      content
      |> String.slice(0, max_length)
      |> String.trim()
      |> Kernel.<>("...")
    end
  end

  def has_spoilers?(content) when is_binary(content) do
    spoiler_keywords = [
      "spoiler", "spoilers", "ending", "dies", "death", "killed",
      "plot twist", "surprise", "reveal", "secret", "finale"
    ]

    content_lower = String.downcase(content)
    Enum.any?(spoiler_keywords, &String.contains?(content_lower, &1))
  end

  def format_review_date(%DateTime{} = datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :day) do
      0 -> "Today"
      1 -> "Yesterday"
      days when days < 7 -> "#{days} days ago"
      days when days < 30 -> "#{div(days, 7)} weeks ago"
      days when days < 365 -> "#{div(days, 30)} months ago"
      _ -> Calendar.strftime(datetime, "%B %Y")
    end
  end

  def rating_percentages(%{total_reviews: 0}), do: %{}
  def rating_percentages(%{total_reviews: total, rating_distribution: distribution}) do
    Enum.into(distribution, %{}, fn {rating, count} ->
      percentage = (count / total) * 100
      {rating, Float.round(percentage, 1)}
    end)
  end

  def format_average_rating(nil), do: "N/A"
  def format_average_rating(rating) when is_number(rating) do
    Float.round(rating, 1) |> to_string()
  end

end
