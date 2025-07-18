defmodule Flixir.Reviews do
  @moduledoc """
  The Reviews context provides business logic for managing movie and TV show reviews.

  This module integrates the cache layer, TMDB API client, and data structures
  to provide a comprehensive review management system with filtering, sorting,
  and pagination capabilities.
  """

  require Logger
  alias Flixir.Reviews.{Review, RatingStats, Cache, TMDBClient}

  @default_per_page 10
  @max_per_page 50

  @doc """
  Fetches reviews for a movie or TV show with optional filtering and pagination.

  ## Parameters
  - `media_type`: Either "movie" or "tv"
  - `media_id`: The TMDB ID of the movie or TV show
  - `opts`: Options for filtering, sorting, and pagination

  ## Options
  - `:page` - Page number (default: 1)
  - `:per_page` - Number of reviews per page (default: 10, max: 50)
  - `:sort_by` - Sort field: `:date`, `:rating`, or `:author` (default: `:date`)
  - `:sort_order` - Sort order: `:asc` or `:desc` (default: `:desc`)
  - `:filter_by_rating` - Filter by rating range: `{min, max}` or `:positive`/`:negative`
  - `:author_filter` - Filter by author name (partial match)

  ## Examples

      iex> Flixir.Reviews.get_reviews("movie", 550)
      {:ok, %{reviews: [%Review{}, ...], pagination: %{...}}}

      iex> Flixir.Reviews.get_reviews("movie", 550, sort_by: :rating, page: 2)
      {:ok, %{reviews: [%Review{}, ...], pagination: %{...}}}

      iex> Flixir.Reviews.get_reviews("invalid", 123)
      {:error, :invalid_media_type}
  """
  def get_reviews(media_type, media_id, opts \\ []) do
    with :ok <- validate_media_params(media_type, media_id),
         {:ok, normalized_opts} <- normalize_options(opts) do

      cache_key_filters = extract_cache_filters(normalized_opts)

      case Cache.get_reviews(media_type, to_string(media_id), cache_key_filters) do
        {:ok, cached_reviews} ->
          Logger.debug("Cache hit for reviews: #{media_type}/#{media_id}")
          process_cached_reviews(cached_reviews, normalized_opts)

        :error ->
          Logger.debug("Cache miss for reviews: #{media_type}/#{media_id}")
          fetch_and_cache_reviews(media_type, media_id, normalized_opts)
      end
    end
  end

  @doc """
  Fetches aggregated rating statistics for a movie or TV show.

  ## Parameters
  - `media_type`: Either "movie" or "tv"
  - `media_id`: The TMDB ID of the movie or TV show

  ## Examples

      iex> Flixir.Reviews.get_rating_stats("movie", 550)
      {:ok, %RatingStats{average_rating: 8.5, total_reviews: 100}}

      iex> Flixir.Reviews.get_rating_stats("invalid", 123)
      {:error, :invalid_media_type}
  """
  def get_rating_stats(media_type, media_id) do
    with :ok <- validate_media_params(media_type, media_id) do
      case Cache.get_ratings(media_type, to_string(media_id)) do
        {:ok, cached_stats} ->
          Logger.debug("Cache hit for rating stats: #{media_type}/#{media_id}")
          {:ok, cached_stats}

        :error ->
          Logger.debug("Cache miss for rating stats: #{media_type}/#{media_id}")
          fetch_and_cache_rating_stats(media_type, media_id)
      end
    end
  end

  @doc """
  Filters a list of reviews based on the provided criteria.

  ## Parameters
  - `reviews`: List of Review structs
  - `filters`: Map of filter criteria

  ## Filter Options
  - `:filter_by_rating` - Filter by rating range or sentiment
  - `:author_filter` - Filter by author name (case-insensitive partial match)
  - `:content_filter` - Filter by content keywords (case-insensitive)

  ## Examples

      iex> reviews = [%Review{rating: 8.0, author: "John"}, %Review{rating: 3.0, author: "Jane"}]
      iex> Flixir.Reviews.filter_reviews(reviews, %{filter_by_rating: :positive})
      [%Review{rating: 8.0, author: "John"}]
  """
  def filter_reviews(reviews, filters) when is_list(reviews) and is_map(filters) do
    reviews
    |> filter_by_rating(Map.get(filters, :filter_by_rating))
    |> filter_by_author(Map.get(filters, :author_filter))
    |> filter_by_content(Map.get(filters, :content_filter))
  end

  @doc """
  Sorts a list of reviews based on the provided criteria.

  ## Parameters
  - `reviews`: List of Review structs
  - `sort_by`: Sort field (`:date`, `:rating`, `:author`)
  - `sort_order`: Sort order (`:asc` or `:desc`)

  ## Examples

      iex> reviews = [%Review{rating: 3.0}, %Review{rating: 8.0}]
      iex> Flixir.Reviews.sort_reviews(reviews, :rating, :desc)
      [%Review{rating: 8.0}, %Review{rating: 3.0}]
  """
  def sort_reviews(reviews, sort_by, sort_order \\ :desc) when is_list(reviews) do
    sorted = case sort_by do
      :date -> Enum.sort_by(reviews, &sort_by_date/1)
      :rating -> Enum.sort_by(reviews, &sort_by_rating/1)
      :author -> Enum.sort_by(reviews, &sort_by_author/1)
      _ -> reviews
    end

    case sort_order do
      :asc -> sorted
      :desc -> Enum.reverse(sorted)
      _ -> sorted
    end
  end

  @doc """
  Paginates a list of reviews.

  ## Parameters
  - `reviews`: List of Review structs
  - `page`: Page number (1-based)
  - `per_page`: Number of reviews per page

  ## Returns
  A map with `:reviews` and `:pagination` keys.

  ## Examples

      iex> reviews = [%Review{}, %Review{}, %Review{}]
      iex> Flixir.Reviews.paginate_reviews(reviews, 1, 2)
      %{
        reviews: [%Review{}, %Review{}],
        pagination: %{page: 1, per_page: 2, total: 3, total_pages: 2}
      }
  """
  def paginate_reviews(reviews, page, per_page) when is_list(reviews) and is_integer(page) and is_integer(per_page) do
    total = length(reviews)
    total_pages = max(1, ceil(total / per_page))

    # Ensure page is within valid range
    page = max(1, min(page, total_pages))

    start_index = (page - 1) * per_page
    paginated_reviews = Enum.slice(reviews, start_index, per_page)

    %{
      reviews: paginated_reviews,
      pagination: %{
        page: page,
        per_page: per_page,
        total: total,
        total_pages: total_pages,
        has_next: page < total_pages,
        has_prev: page > 1
      }
    }
  end

  # Private functions

  defp validate_media_params(media_type, media_id) do
    cond do
      media_type not in ["movie", "tv"] ->
        {:error, :invalid_media_type}

      not is_integer(media_id) or media_id <= 0 ->
        {:error, :invalid_media_id}

      true ->
        :ok
    end
  end

  defp normalize_options(opts) do
    normalized = %{
      page: Keyword.get(opts, :page, 1),
      per_page: min(Keyword.get(opts, :per_page, @default_per_page), @max_per_page),
      sort_by: Keyword.get(opts, :sort_by, :date),
      sort_order: Keyword.get(opts, :sort_order, :desc),
      filter_by_rating: Keyword.get(opts, :filter_by_rating),
      author_filter: Keyword.get(opts, :author_filter),
      content_filter: Keyword.get(opts, :content_filter)
    }

    # Validate options
    with :ok <- validate_page(normalized.page),
         :ok <- validate_per_page(normalized.per_page),
         :ok <- validate_sort_options(normalized.sort_by, normalized.sort_order) do
      {:ok, normalized}
    end
  end

  defp validate_page(page) when is_integer(page) and page > 0, do: :ok
  defp validate_page(_), do: {:error, :invalid_page}

  defp validate_per_page(per_page) when is_integer(per_page) and per_page > 0 and per_page <= @max_per_page, do: :ok
  defp validate_per_page(_), do: {:error, :invalid_per_page}

  defp validate_sort_options(sort_by, sort_order) do
    valid_sort_by = sort_by in [:date, :rating, :author]
    valid_sort_order = sort_order in [:asc, :desc]

    cond do
      not valid_sort_by -> {:error, :invalid_sort_by}
      not valid_sort_order -> {:error, :invalid_sort_order}
      true -> :ok
    end
  end

  defp extract_cache_filters(opts) do
    # Only include filters that affect the cached data
    %{}
    |> maybe_put(:filter_by_rating, opts.filter_by_rating)
    |> maybe_put(:author_filter, opts.author_filter)
    |> maybe_put(:content_filter, opts.content_filter)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp process_cached_reviews(cached_reviews, opts) do
    result = cached_reviews
    |> filter_reviews(opts)
    |> sort_reviews(opts.sort_by, opts.sort_order)
    |> paginate_reviews(opts.page, opts.per_page)

    {:ok, result}
  end

  defp fetch_and_cache_reviews(media_type, media_id, opts) do
    # For now, fetch only the first page from API and handle pagination in memory
    # This could be optimized later to fetch specific pages from API
    case TMDBClient.fetch_reviews(media_type, media_id, 1) do
      {:ok, %{reviews: reviews}} ->
        # Cache the raw reviews
        cache_key_filters = extract_cache_filters(opts)
        Cache.put_reviews(media_type, to_string(media_id), reviews, cache_key_filters)

        # Process and return filtered/sorted/paginated results
        result = reviews
        |> filter_reviews(opts)
        |> sort_reviews(opts.sort_by, opts.sort_order)
        |> paginate_reviews(opts.page, opts.per_page)

        {:ok, result}

      {:error, reason} ->
        Logger.error("Failed to fetch reviews for #{media_type}/#{media_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_and_cache_rating_stats(media_type, media_id) do
    case TMDBClient.fetch_reviews(media_type, media_id, 1) do
      {:ok, %{reviews: reviews}} ->
        stats = calculate_rating_stats(reviews)
        Cache.put_ratings(media_type, to_string(media_id), stats)
        {:ok, stats}

      {:error, reason} ->
        Logger.error("Failed to fetch rating stats for #{media_type}/#{media_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp calculate_rating_stats(reviews) do
    reviews_with_ratings = Enum.filter(reviews, & &1.rating)
    total_reviews = length(reviews)

    if length(reviews_with_ratings) > 0 do
      ratings = Enum.map(reviews_with_ratings, & &1.rating)
      average_rating = Enum.sum(ratings) / length(ratings)

      rating_distribution =
        ratings
        |> Enum.map(&round/1)
        |> Enum.frequencies()
        |> Enum.into(%{}, fn {rating, count} -> {to_string(rating), count} end)

      {:ok, stats} = RatingStats.new(%{
        average_rating: average_rating,
        total_reviews: total_reviews,
        rating_distribution: rating_distribution
      })

      stats
    else
      {:ok, stats} = RatingStats.new(%{total_reviews: total_reviews})
      stats
    end
  end

  # Filter functions

  defp filter_by_rating(reviews, nil), do: reviews
  defp filter_by_rating(reviews, :positive) do
    Enum.filter(reviews, fn review ->
      review.rating && review.rating >= 6.0
    end)
  end
  defp filter_by_rating(reviews, :negative) do
    Enum.filter(reviews, fn review ->
      review.rating && review.rating < 6.0
    end)
  end
  defp filter_by_rating(reviews, {min_rating, max_rating}) when is_number(min_rating) and is_number(max_rating) do
    Enum.filter(reviews, fn review ->
      review.rating && review.rating >= min_rating && review.rating <= max_rating
    end)
  end
  defp filter_by_rating(reviews, _), do: reviews

  defp filter_by_author(reviews, nil), do: reviews
  defp filter_by_author(reviews, author_filter) when is_binary(author_filter) do
    filter_lower = String.downcase(author_filter)
    Enum.filter(reviews, fn review ->
      String.contains?(String.downcase(review.author), filter_lower)
    end)
  end
  defp filter_by_author(reviews, _), do: reviews

  defp filter_by_content(reviews, nil), do: reviews
  defp filter_by_content(reviews, content_filter) when is_binary(content_filter) do
    filter_lower = String.downcase(content_filter)
    Enum.filter(reviews, fn review ->
      String.contains?(String.downcase(review.content), filter_lower)
    end)
  end
  defp filter_by_content(reviews, _), do: reviews

  # Sort functions

  defp sort_by_date(%Review{created_at: nil}), do: ~U[1970-01-01 00:00:00Z]
  defp sort_by_date(%Review{created_at: date}), do: date

  defp sort_by_rating(%Review{rating: nil}), do: 0
  defp sort_by_rating(%Review{rating: rating}), do: rating

  defp sort_by_author(%Review{author: author}), do: String.downcase(author)
end
