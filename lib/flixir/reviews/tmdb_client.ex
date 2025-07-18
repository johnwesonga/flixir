defmodule Flixir.Reviews.TMDBClient do
  @moduledoc """
  HTTP client for fetching reviews from The Movie Database (TMDB) API.

  Handles API communication, response parsing, error handling, and retry logic
  for movie and TV show reviews.
  """

  require Logger
  alias Flixir.Reviews.Review

  @base_url "https://api.themoviedb.org/3"
  @default_timeout 5_000
  @default_max_retries 3

  @doc """
  Fetches reviews for a movie or TV show from TMDB API.

  ## Parameters
  - `media_type`: Either "movie" or "tv"
  - `media_id`: The TMDB ID of the movie or TV show
  - `page`: Page number for pagination (default: 1)

  ## Examples

      iex> Flixir.Reviews.TMDBClient.fetch_reviews("movie", 550, 1)
      {:ok, %{reviews: [%Review{}, ...], total_pages: 5, total_results: 100}}

      iex> Flixir.Reviews.TMDBClient.fetch_reviews("invalid", 123)
      {:error, :invalid_media_type}
  """
  def fetch_reviews(media_type, media_id, page \\ 1)

  def fetch_reviews(media_type, media_id, page) when media_type in ["movie", "tv"] and is_integer(media_id) and media_id > 0 and is_integer(page) and page > 0 do
    url = build_reviews_url(media_type, media_id, page)

    case make_request(url) do
      {:ok, response_body} ->
        parse_reviews_response(response_body)

      {:error, reason} ->
        Logger.error("Failed to fetch reviews for #{media_type}/#{media_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def fetch_reviews(media_type, _media_id, _page) when media_type not in ["movie", "tv"] do
    {:error, :invalid_media_type}
  end

  def fetch_reviews(_media_type, media_id, _page) when not is_integer(media_id) or media_id <= 0 do
    {:error, :invalid_media_id}
  end

  def fetch_reviews(_media_type, _media_id, page) when not is_integer(page) or page <= 0 do
    {:error, :invalid_page}
  end

  @doc """
  Parses a TMDB reviews API response into a structured format.

  ## Examples

      iex> response = %{
      ...>   "results" => [
      ...>     %{
      ...>       "id" => "123",
      ...>       "author" => "John Doe",
      ...>       "content" => "Great movie!",
      ...>       "created_at" => "2023-01-01T00:00:00.000Z"
      ...>     }
      ...>   ],
      ...>   "total_pages" => 1,
      ...>   "total_results" => 1
      ...> }
      iex> Flixir.Reviews.TMDBClient.parse_reviews_response(response)
      {:ok, %{reviews: [%Review{}], total_pages: 1, total_results: 1}}
  """
  def parse_reviews_response(%{"results" => results} = response) when is_list(results) do
    reviews =
      results
      |> Enum.map(&parse_single_review/1)
      |> Enum.filter(fn
        {:ok, _review} -> true
        {:error, _reason} -> false
      end)
      |> Enum.map(fn {:ok, review} -> review end)

    parsed_response = %{
      reviews: reviews,
      total_pages: Map.get(response, "total_pages", 1),
      total_results: Map.get(response, "total_results", length(reviews)),
      page: Map.get(response, "page", 1)
    }

    {:ok, parsed_response}
  end

  def parse_reviews_response(%{} = response) do
    Logger.warning("Unexpected TMDB response format: #{inspect(response)}")
    {:error, :invalid_response_format}
  end

  def parse_reviews_response(_response) do
    {:error, :invalid_response_format}
  end

  @doc """
  Builds the complete URL for fetching reviews from TMDB API.

  ## Examples

      iex> Flixir.Reviews.TMDBClient.build_reviews_url("movie", 550, 1)
      "https://api.themoviedb.org/3/movie/550/reviews?api_key=...&page=1"
  """
  def build_reviews_url(media_type, media_id, page) do
    api_key = get_api_key()
    "#{@base_url}/#{media_type}/#{media_id}/reviews?api_key=#{api_key}&page=#{page}"
  end

  # Private functions

  defp make_request(url) do
    options = [
      timeout: get_timeout(),
      retry: :transient,
      max_retries: get_max_retries(),
      retry_delay: fn attempt -> :timer.seconds(2 ** attempt) end
    ]

    case Req.get(url, options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: 401}} ->
        Logger.error("TMDB API authentication failed - check API key")
        {:error, :unauthorized}

      {:ok, %Req.Response{status: 404}} ->
        Logger.warning("TMDB resource not found: #{url}")
        {:error, :not_found}

      {:ok, %Req.Response{status: 429}} ->
        Logger.warning("TMDB API rate limit exceeded")
        {:error, :rate_limited}

      {:ok, %Req.Response{status: status}} ->
        Logger.error("TMDB API returned unexpected status: #{status}")
        {:error, {:unexpected_status, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        Logger.error("TMDB API request timed out")
        {:error, :timeout}

      {:error, %Req.TransportError{reason: reason}} ->
        Logger.error("TMDB API transport error: #{inspect(reason)}")
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        Logger.error("TMDB API request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_single_review(review_data) when is_map(review_data) do
    attrs = %{
      id: Map.get(review_data, "id"),
      author: Map.get(review_data, "author"),
      author_details: Map.get(review_data, "author_details", %{}),
      content: Map.get(review_data, "content"),
      created_at: Map.get(review_data, "created_at"),
      updated_at: Map.get(review_data, "updated_at"),
      url: Map.get(review_data, "url"),
      rating: extract_rating(review_data)
    }

    Review.new(attrs)
  end

  defp parse_single_review(invalid_data) do
    Logger.warning("Invalid review data format: #{inspect(invalid_data)}")
    {:error, :invalid_review_format}
  end

  defp extract_rating(%{"author_details" => %{"rating" => rating}}) when is_number(rating) do
    rating
  end

  defp extract_rating(_), do: nil

  defp get_api_key do
    case Application.get_env(:flixir, :tmdb)[:api_key] do
      nil ->
        Logger.error("TMDB API key not configured")
        raise "TMDB API key not found. Please set TMDB_API_KEY environment variable."

      api_key when is_binary(api_key) and api_key != "" ->
        api_key

      _ ->
        Logger.error("Invalid TMDB API key configuration")
        raise "Invalid TMDB API key configuration"
    end
  end

  defp get_timeout do
    Application.get_env(:flixir, :tmdb)[:timeout] || @default_timeout
  end

  defp get_max_retries do
    Application.get_env(:flixir, :tmdb)[:max_retries] || @default_max_retries
  end
end
