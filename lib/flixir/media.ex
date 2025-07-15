defmodule Flixir.Media do
  @moduledoc """
  The Media context provides business logic for searching and managing movie and TV show content.

  This context orchestrates interactions between the TMDB API client, caching layer,
  and data transformation to provide a unified interface for media search functionality.
  """

  alias Flixir.Media.{TMDBClient, Cache, SearchResult, SearchParams}
  require Logger

  @doc """
  Searches for movies and TV shows based on the provided query and options.

  This function orchestrates the search process by:
  1. Validating search parameters
  2. Checking cache for existing results
  3. Making API calls if needed
  4. Filtering and sorting results
  5. Caching successful responses

  ## Parameters
  - query: Search term string
  - opts: Keyword list of options including:
    - :media_type - :all, :movie, or :tv (default: :all)
    - :sort_by - :relevance, :release_date, :title, or :popularity (default: :relevance)
    - :page - Page number for pagination (default: 1)

  ## Returns
  - {:ok, results} - List of SearchResult structs
  - {:error, reason} - Error tuple with reason

  ## Examples
      iex> Flixir.Media.search_content("batman")
      {:ok, [%Flixir.Media.SearchResult{}, ...]}

      iex> Flixir.Media.search_content("batman", media_type: :movie, sort_by: :release_date)
      {:ok, [%Flixir.Media.SearchResult{}, ...]}
  """
  @spec search_content(String.t(), keyword()) :: {:ok, [SearchResult.t()]} | {:error, term()}
  def search_content(query, opts \\ []) do
    with {:ok, search_params} <- build_search_params(query, opts),
         {:ok, results} <- get_search_results(search_params) do

      filtered_results = filter_results(results, search_params.media_type)
      sorted_results = sort_results(filtered_results, search_params.sort_by)

      {:ok, sorted_results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Retrieves detailed information for a specific movie or TV show.

  ## Parameters
  - id: TMDB content ID
  - type: :movie or :tv

  ## Returns
  - {:ok, details} - Detailed content information
  - {:error, reason} - Error tuple with reason
  """
  @spec get_content_details(integer(), :movie | :tv) :: {:ok, map()} | {:error, term()}
  def get_content_details(id, type) when type in [:movie, :tv] and is_integer(id) do
    cache_key = "details:#{type}:#{id}"

    case Cache.get(cache_key) do
      {:ok, cached_details} ->
        Logger.debug("Cache hit for content details: #{type}:#{id}")
        {:ok, cached_details}

      :error ->
        Logger.debug("Cache miss for content details: #{type}:#{id}")
        fetch_and_cache_details(id, type, cache_key)
    end
  end

  def get_content_details(_id, type) when type not in [:movie, :tv] do
    {:error, "Invalid content type. Must be :movie or :tv"}
  end

  def get_content_details(id, _type) when not is_integer(id) do
    {:error, "Invalid content ID. Must be an integer"}
  end

  @doc """
  Clears the search cache.

  This function removes all cached search results and content details.
  """
  @spec clear_search_cache() :: :ok
  def clear_search_cache do
    Cache.clear()
    Logger.info("Search cache cleared")
    :ok
  end

  @doc """
  Returns cache statistics for monitoring and debugging.

  ## Returns
  Map containing cache statistics including hits, misses, size, and memory usage.
  """
  @spec cache_stats() :: map()
  def cache_stats do
    Cache.stats()
  end

  # Private Functions

  defp build_search_params(query, opts) do
    params = %{
      "query" => query,
      "media_type" => Keyword.get(opts, :media_type, :all),
      "sort_by" => Keyword.get(opts, :sort_by, :relevance),
      "page" => Keyword.get(opts, :page, 1)
    }

    SearchParams.new(params)
  end

  defp get_search_results(search_params) do
    cache_key = Cache.search_key(
      search_params.query,
      media_type: search_params.media_type,
      sort_by: search_params.sort_by,
      page: search_params.page
    )

    case Cache.get(cache_key) do
      {:ok, cached_results} ->
        Logger.debug("Cache hit for search: #{search_params.query}")
        {:ok, cached_results}

      :error ->
        Logger.debug("Cache miss for search: #{search_params.query}")
        fetch_and_cache_search_results(search_params, cache_key)
    end
  end

  defp fetch_and_cache_search_results(search_params, cache_key) do
    api_params = SearchParams.to_api_params(search_params)

    case TMDBClient.search_multi(api_params["query"], api_params["page"]) do
      {:ok, response} ->
        case transform_api_response(response) do
          {:ok, results} ->
            # Cache successful results for 5 minutes
            Cache.put(cache_key, results, 300)
            Logger.info("Cached search results for query: #{search_params.query}")
            {:ok, results}

          {:error, reason} ->
            Logger.error("Failed to transform API response: #{inspect(reason)}")
            {:error, {:transformation_error, reason}}
        end

      {:error, reason} ->
        Logger.error("TMDB API search failed: #{inspect(reason)}")
        handle_api_error(reason)
    end
  end

  defp fetch_and_cache_details(id, type, cache_key) do
    api_call = case type do
      :movie -> fn -> TMDBClient.get_movie_details(id) end
      :tv -> fn -> TMDBClient.get_tv_details(id) end
    end

    case api_call.() do
      {:ok, details} ->
        # Cache details for 30 minutes
        Cache.put(cache_key, details, 1800)
        Logger.info("Cached content details for #{type}:#{id}")
        {:ok, details}

      {:error, reason} ->
        Logger.error("TMDB API details fetch failed for #{type}:#{id}: #{inspect(reason)}")
        handle_api_error(reason)
    end
  end

  defp transform_api_response(%{"results" => results}) when is_list(results) do
    transformed_results =
      results
      |> Enum.map(&SearchResult.from_tmdb_data/1)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, result}, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
        {:error, reason}, _acc -> {:halt, {:error, reason}}
      end)

    case transformed_results do
      {:ok, results_list} -> {:ok, Enum.reverse(results_list)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transform_api_response(response) do
    Logger.warning("Unexpected API response format: #{inspect(response)}")
    {:error, "Invalid API response format"}
  end

  defp filter_results(results, :all), do: results
  defp filter_results(results, media_type) do
    Enum.filter(results, fn result -> result.media_type == media_type end)
  end

  defp sort_results(results, :relevance), do: results  # API returns by relevance by default
  defp sort_results(results, :popularity) do
    Enum.sort_by(results, & &1.popularity, :desc)
  end
  defp sort_results(results, :release_date) do
    Enum.sort_by(results, fn result ->
      case result.release_date do
        nil -> ~D[1900-01-01]  # Put items without dates at the beginning
        date -> date
      end
    end, :desc)
  end
  defp sort_results(results, :title) do
    Enum.sort_by(results, & String.downcase(&1.title))
  end

  defp handle_api_error({:timeout, _message}) do
    {:error, {:timeout, "Search request timed out. Please try again."}}
  end

  defp handle_api_error({:rate_limited, _message, _body}) do
    {:error, {:rate_limited, "Too many requests. Please wait a moment and try again."}}
  end

  defp handle_api_error({:unauthorized, _message, _body}) do
    {:error, {:unauthorized, "API authentication failed. Please check configuration."}}
  end

  defp handle_api_error({:api_error, status, body}) do
    Logger.error("TMDB API error #{status}: #{inspect(body)}")
    {:error, {:api_error, "Search service temporarily unavailable. Please try again later."}}
  end

  defp handle_api_error({:request_failed, reason}) do
    Logger.error("HTTP request failed: #{inspect(reason)}")
    {:error, {:network_error, "Network error occurred. Please check your connection and try again."}}
  end

  defp handle_api_error(reason) do
    Logger.error("Unexpected API error: #{inspect(reason)}")
    {:error, {:unknown_error, "An unexpected error occurred. Please try again."}}
  end
end
