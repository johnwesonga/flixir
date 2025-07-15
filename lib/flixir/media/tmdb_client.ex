defmodule Flixir.Media.TMDBClient do
  @moduledoc """
  Client for The Movie Database (TMDB) API integration.
  
  Provides functions to interact with TMDB API endpoints for searching
  movies and TV shows, fetching details, and handling API responses.
  """

  @doc """
  Searches for movies and TV shows using TMDB's multi-search endpoint.
  
  ## Parameters
  - query: Search term string
  - page: Page number for pagination (default: 1)
  
  ## Returns
  - {:ok, response} on successful API call
  - {:error, reason} on failure
  """
  def search_multi(query, page \\ 1) do
    params = %{
      query: query,
      page: page,
      api_key: api_key()
    }
    
    get("/search/multi", params)
  end

  @doc """
  Fetches detailed information for a specific movie.
  
  ## Parameters
  - movie_id: TMDB movie ID
  
  ## Returns
  - {:ok, response} on successful API call
  - {:error, reason} on failure
  """
  def get_movie_details(movie_id) do
    params = %{api_key: api_key()}
    get("/movie/#{movie_id}", params)
  end

  @doc """
  Fetches detailed information for a specific TV show.
  
  ## Parameters
  - tv_id: TMDB TV show ID
  
  ## Returns
  - {:ok, response} on successful API call
  - {:error, reason} on failure
  """
  def get_tv_details(tv_id) do
    params = %{api_key: api_key()}
    get("/tv/#{tv_id}", params)
  end

  # Private functions

  defp get(path, params) do
    url = base_url() <> path
    
    request_options = [
      params: params,
      headers: headers(),
      receive_timeout: timeout(),
      retry: :transient,
      max_retries: max_retries()
    ]
    
    case Req.get(url, request_options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %Req.Response{status: 401, body: body}} ->
        {:error, {:unauthorized, "Invalid API key", body}}
      
      {:ok, %Req.Response{status: 429, body: body}} ->
        {:error, {:rate_limited, "Too many requests", body}}
      
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:api_error, status, body}}
      
      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, {:timeout, "Request timed out"}}
      
      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp headers do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "Flixir/1.0"}
    ]
  end

  defp base_url do
    Application.get_env(:flixir, :tmdb)[:base_url] || "https://api.themoviedb.org/3"
  end

  defp api_key do
    Application.get_env(:flixir, :tmdb)[:api_key] || 
      raise "TMDB API key not configured. Please set TMDB_API_KEY environment variable."
  end

  defp timeout do
    Application.get_env(:flixir, :tmdb)[:timeout] || 5_000
  end

  defp max_retries do
    Application.get_env(:flixir, :tmdb)[:max_retries] || 3
  end
end