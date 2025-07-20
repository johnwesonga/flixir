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
    - :return_format - :list (legacy format, default) or :map (new format with pagination)

  ## Returns
  - {:ok, results} - List of SearchResult structs (legacy format)
  - {:ok, %{results: results, has_more: boolean}} - Map with results and pagination info (new format)
  - {:error, reason} - Error tuple with reason

  ## Examples
      iex> Flixir.Media.search_content("batman")
      {:ok, [%Flixir.Media.SearchResult{}, ...]}

      iex> Flixir.Media.search_content("batman", return_format: :map)
      {:ok, %{results: [%Flixir.Media.SearchResult{}, ...], has_more: true}}
  """
  @spec search_content(String.t(), keyword()) :: {:ok, [SearchResult.t()] | %{results: [SearchResult.t()], has_more: boolean()}} | {:error, term()}
  def search_content(query, opts \\ []) do
    return_format = Keyword.get(opts, :return_format, :list)

    with {:ok, search_params} <- build_search_params(query, opts),
         {:ok, search_results} <- get_search_results(search_params) do

      # Handle both legacy list format and new map format
      {results, has_more} = case search_results do
        %{results: results, has_more: has_more} -> {results, has_more}
        results when is_list(results) -> {results, false}
      end

      filtered_results = filter_results(results, search_params.media_type)
      sorted_results = sort_results(filtered_results, search_params.sort_by)

      # Limit to 20 results per page for performance
      page_results = Enum.take(sorted_results, 20)
      actual_has_more = has_more or length(sorted_results) > 20

      case return_format do
        :map -> {:ok, %{results: page_results, has_more: actual_has_more}}
        :list -> {:ok, page_results}
      end
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
  Retrieves popular movies from TMDB.

  ## Parameters
  - opts: Keyword list of options including:
    - :page - Page number for pagination (default: 1)
    - :return_format - :list (legacy format, default) or :map (new format with pagination)

  ## Returns
  - {:ok, results} - List of SearchResult structs (legacy format)
  - {:ok, %{results: results, has_more: boolean}} - Map with results and pagination info (new format)
  - {:error, reason} - Error tuple with reason

  ## Examples
      iex> Flixir.Media.get_popular_movies()
      {:ok, [%Flixir.Media.SearchResult{}, ...]}

      iex> Flixir.Media.get_popular_movies(return_format: :map)
      {:ok, %{results: [%Flixir.Media.SearchResult{}, ...], has_more: true}}
  """
  @spec get_popular_movies(keyword()) :: {:ok, [SearchResult.t()] | %{results: [SearchResult.t()], has_more: boolean()}} | {:error, term()}
  def get_popular_movies(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    return_format = Keyword.get(opts, :return_format, :list)

    cache_key = "movies:popular:page:#{page}"

    case Cache.get(cache_key) do
      {:ok, cached_results} ->
        Logger.debug("Cache hit for popular movies, page #{page}")
        format_movie_list_response(cached_results, return_format)

      :error ->
        Logger.debug("Cache miss for popular movies, page #{page}")
        fetch_and_cache_movie_list(:popular, page, cache_key, return_format)
    end
  end

  @doc """
  Retrieves trending movies from TMDB.

  ## Parameters
  - opts: Keyword list of options including:
    - :time_window - "day" or "week" (default: "week")
    - :page - Page number for pagination (default: 1)
    - :return_format - :list (legacy format, default) or :map (new format with pagination)

  ## Returns
  - {:ok, results} - List of SearchResult structs (legacy format)
  - {:ok, %{results: results, has_more: boolean}} - Map with results and pagination info (new format)
  - {:error, reason} - Error tuple with reason

  ## Examples
      iex> Flixir.Media.get_trending_movies()
      {:ok, [%Flixir.Media.SearchResult{}, ...]}

      iex> Flixir.Media.get_trending_movies(time_window: "day", return_format: :map)
      {:ok, %{results: [%Flixir.Media.SearchResult{}, ...], has_more: true}}
  """
  @spec get_trending_movies(keyword()) :: {:ok, [SearchResult.t()] | %{results: [SearchResult.t()], has_more: boolean()}} | {:error, term()}
  def get_trending_movies(opts \\ []) do
    time_window = Keyword.get(opts, :time_window, "week")
    page = Keyword.get(opts, :page, 1)
    return_format = Keyword.get(opts, :return_format, :list)

    cache_key = "movies:trending:#{time_window}:page:#{page}"

    case Cache.get(cache_key) do
      {:ok, cached_results} ->
        Logger.debug("Cache hit for trending movies (#{time_window}), page #{page}")
        format_movie_list_response(cached_results, return_format)

      :error ->
        Logger.debug("Cache miss for trending movies (#{time_window}), page #{page}")
        fetch_and_cache_movie_list({:trending, time_window}, page, cache_key, return_format)
    end
  end

  @doc """
  Retrieves top-rated movies from TMDB.

  ## Parameters
  - opts: Keyword list of options including:
    - :page - Page number for pagination (default: 1)
    - :return_format - :list (legacy format, default) or :map (new format with pagination)

  ## Returns
  - {:ok, results} - List of SearchResult structs (legacy format)
  - {:ok, %{results: results, has_more: boolean}} - Map with results and pagination info (new format)
  - {:error, reason} - Error tuple with reason

  ## Examples
      iex> Flixir.Media.get_top_rated_movies()
      {:ok, [%Flixir.Media.SearchResult{}, ...]}

      iex> Flixir.Media.get_top_rated_movies(return_format: :map)
      {:ok, %{results: [%Flixir.Media.SearchResult{}, ...], has_more: true}}
  """
  @spec get_top_rated_movies(keyword()) :: {:ok, [SearchResult.t()] | %{results: [SearchResult.t()], has_more: boolean()}} | {:error, term()}
  def get_top_rated_movies(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    return_format = Keyword.get(opts, :return_format, :list)

    cache_key = "movies:top_rated:page:#{page}"

    case Cache.get(cache_key) do
      {:ok, cached_results} ->
        Logger.debug("Cache hit for top-rated movies, page #{page}")
        format_movie_list_response(cached_results, return_format)

      :error ->
        Logger.debug("Cache miss for top-rated movies, page #{page}")
        fetch_and_cache_movie_list(:top_rated, page, cache_key, return_format)
    end
  end

  @doc """
  Retrieves upcoming movies from TMDB.

  ## Parameters
  - opts: Keyword list of options including:
    - :page - Page number for pagination (default: 1)
    - :return_format - :list (legacy format, default) or :map (new format with pagination)

  ## Returns
  - {:ok, results} - List of SearchResult structs (legacy format)
  - {:ok, %{results: results, has_more: boolean}} - Map with results and pagination info (new format)
  - {:error, reason} - Error tuple with reason

  ## Examples
      iex> Flixir.Media.get_upcoming_movies()
      {:ok, [%Flixir.Media.SearchResult{}, ...]}

      iex> Flixir.Media.get_upcoming_movies(return_format: :map)
      {:ok, %{results: [%Flixir.Media.SearchResult{}, ...], has_more: true}}
  """
  @spec get_upcoming_movies(keyword()) :: {:ok, [SearchResult.t()] | %{results: [SearchResult.t()], has_more: boolean()}} | {:error, term()}
  def get_upcoming_movies(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    return_format = Keyword.get(opts, :return_format, :list)

    cache_key = "movies:upcoming:page:#{page}"

    case Cache.get(cache_key) do
      {:ok, cached_results} ->
        Logger.debug("Cache hit for upcoming movies, page #{page}")
        format_movie_list_response(cached_results, return_format)

      :error ->
        Logger.debug("Cache miss for upcoming movies, page #{page}")
        fetch_and_cache_movie_list(:upcoming, page, cache_key, return_format)
    end
  end

  @doc """
  Retrieves now playing movies from TMDB.

  ## Parameters
  - opts: Keyword list of options including:
    - :page - Page number for pagination (default: 1)
    - :return_format - :list (legacy format, default) or :map (new format with pagination)

  ## Returns
  - {:ok, results} - List of SearchResult structs (legacy format)
  - {:ok, %{results: results, has_more: boolean}} - Map with results and pagination info (new format)
  - {:error, reason} - Error tuple with reason

  ## Examples
      iex> Flixir.Media.get_now_playing_movies()
      {:ok, [%Flixir.Media.SearchResult{}, ...]}

      iex> Flixir.Media.get_now_playing_movies(return_format: :map)
      {:ok, %{results: [%Flixir.Media.SearchResult{}, ...], has_more: true}}
  """
  @spec get_now_playing_movies(keyword()) :: {:ok, [SearchResult.t()] | %{results: [SearchResult.t()], has_more: boolean()}} | {:error, term()}
  def get_now_playing_movies(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    return_format = Keyword.get(opts, :return_format, :list)

    cache_key = "movies:now_playing:page:#{page}"

    case Cache.get(cache_key) do
      {:ok, cached_results} ->
        Logger.debug("Cache hit for now playing movies, page #{page}")
        format_movie_list_response(cached_results, return_format)

      :error ->
        Logger.debug("Cache miss for now playing movies, page #{page}")
        fetch_and_cache_movie_list(:now_playing, page, cache_key, return_format)
    end
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
        case transform_api_response(response, search_params.page) do
          {:ok, result_data} ->
            # Cache successful results for 5 minutes
            Cache.put(cache_key, result_data, 300)
            Logger.info("Cached search results for query: #{search_params.query}")
            {:ok, result_data}

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

  defp transform_api_response(%{"results" => results, "total_pages" => total_pages, "page" => current_page}, current_page) when is_list(results) do
    transformed_results =
      results
      |> Enum.map(&SearchResult.from_tmdb_data/1)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, result}, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
        {:error, reason}, _acc -> {:halt, {:error, reason}}
      end)

    case transformed_results do
      {:ok, results_list} ->
        has_more = current_page < total_pages
        {:ok, %{results: Enum.reverse(results_list), has_more: has_more}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transform_api_response(%{"results" => results}, _current_page) when is_list(results) do
    # Fallback for responses without pagination info
    transformed_results =
      results
      |> Enum.map(&SearchResult.from_tmdb_data/1)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, result}, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
        {:error, reason}, _acc -> {:halt, {:error, reason}}
      end)

    case transformed_results do
      {:ok, results_list} ->
        # Assume there might be more results if we got 20 results
        has_more = length(results_list) >= 20
        {:ok, %{results: Enum.reverse(results_list), has_more: has_more}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transform_api_response(response, _current_page) do
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

  defp format_movie_list_response(cached_results, return_format) do
    case return_format do
      :map -> {:ok, cached_results}
      :list ->
        case cached_results do
          %{results: results} -> {:ok, results}
          results when is_list(results) -> {:ok, results}
        end
    end
  end

  defp fetch_and_cache_movie_list(list_type, page, cache_key, return_format) do
    api_call = case list_type do
      :popular -> fn -> TMDBClient.get_popular_movies(page) end
      {:trending, time_window} -> fn -> TMDBClient.get_trending_movies(time_window, page) end
      :top_rated -> fn -> TMDBClient.get_top_rated_movies(page) end
      :upcoming -> fn -> TMDBClient.get_upcoming_movies(page) end
      :now_playing -> fn -> TMDBClient.get_now_playing_movies(page) end
    end

    case api_call.() do
      {:ok, response} ->
        case transform_movie_list_response(response, page) do
          {:ok, result_data} ->
            # Cache successful results for 15 minutes (longer than search results)
            Cache.put(cache_key, result_data, 900)
            Logger.info("Cached movie list results for #{inspect(list_type)}, page #{page}")
            format_movie_list_response(result_data, return_format)

          {:error, reason} ->
            Logger.error("Failed to transform movie list API response: #{inspect(reason)}")
            {:error, {:transformation_error, reason}}
        end

      {:error, reason} ->
        Logger.error("TMDB API movie list fetch failed for #{inspect(list_type)}: #{inspect(reason)}")
        handle_api_error(reason)
    end
  end

  defp transform_movie_list_response(%{"results" => results, "total_pages" => total_pages, "page" => current_page}, current_page) when is_list(results) do
    # Transform all results to SearchResult structs with media_type set to :movie
    transformed_results =
      results
      |> Enum.map(fn movie_data ->
        # Ensure media_type is set to "movie" for movie list results
        movie_data_with_type = Map.put(movie_data, "media_type", "movie")
        SearchResult.from_tmdb_data(movie_data_with_type)
      end)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, result}, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
        {:error, reason}, _acc -> {:halt, {:error, reason}}
      end)

    case transformed_results do
      {:ok, results_list} ->
        has_more = current_page < total_pages
        {:ok, %{results: Enum.reverse(results_list), has_more: has_more}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transform_movie_list_response(%{"results" => results}, _current_page) when is_list(results) do
    # Fallback for responses without pagination info
    transformed_results =
      results
      |> Enum.map(fn movie_data ->
        # Ensure media_type is set to "movie" for movie list results
        movie_data_with_type = Map.put(movie_data, "media_type", "movie")
        SearchResult.from_tmdb_data(movie_data_with_type)
      end)
      |> Enum.reduce_while({:ok, []}, fn
        {:ok, result}, {:ok, acc} -> {:cont, {:ok, [result | acc]}}
        {:error, reason}, _acc -> {:halt, {:error, reason}}
      end)

    case transformed_results do
      {:ok, results_list} ->
        # Assume there might be more results if we got 20 results
        has_more = length(results_list) >= 20
        {:ok, %{results: Enum.reverse(results_list), has_more: has_more}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp transform_movie_list_response(response, _current_page) do
    Logger.warning("Unexpected movie list API response format: #{inspect(response)}")
    {:error, "Invalid API response format"}
  end
end
