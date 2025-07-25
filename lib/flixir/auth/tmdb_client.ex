defmodule Flixir.Auth.TMDBClient do
  @moduledoc """
  HTTP client for TMDB authentication operations.

  Handles the three-step TMDB authentication flow:
  1. Request token creation
  2. Token validation with user credentials (handled by TMDB website)
  3. Session creation from approved token

  Also provides functions for session management and user account details.
  """

  require Logger

  @base_url "https://api.themoviedb.org/3"
  @default_timeout 5_000
  @default_max_retries 3

  @doc """
  Creates a new request token from TMDB API.

  This is the first step in the TMDB authentication flow. The returned token
  must be approved by the user on the TMDB website before it can be used to
  create a session.

  ## Returns
  - `{:ok, %{request_token: token, expires_at: datetime}}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> Flixir.Auth.TMDBClient.create_request_token()
      {:ok, %{
        request_token: "abc123...",
        expires_at: "2024-01-01 12:00:00 UTC"
      }}
  """
  def create_request_token do
    url = build_url("/authentication/token/new")

    case make_request(:get, url) do
      {:ok, response_body} ->
        parse_token_response(response_body)

      {:error, reason} ->
        Logger.error("Failed to create request token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Creates a session from an approved request token.

  This is the final step in the TMDB authentication flow. The token must have
  been approved by the user on the TMDB website.

  ## Parameters
  - `request_token`: The approved request token from TMDB

  ## Returns
  - `{:ok, %{session_id: session_id}}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> Flixir.Auth.TMDBClient.create_session("approved_token_123")
      {:ok, %{session_id: "session_abc123..."}}
  """
  def create_session(request_token) when is_binary(request_token) do
    url = build_url("/authentication/session/new")
    body = %{request_token: request_token}

    case make_request(:post, url, body) do
      {:ok, response_body} ->
        parse_session_response(response_body)

      {:error, reason} ->
        Logger.error("Failed to create session with token #{request_token}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def create_session(_invalid_token) do
    {:error, :invalid_token}
  end

  @doc """
  Deletes/invalidates a TMDB session.

  ## Parameters
  - `session_id`: The session ID to invalidate

  ## Returns
  - `{:ok, %{success: true}}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> Flixir.Auth.TMDBClient.delete_session("session_123")
      {:ok, %{success: true}}
  """
  def delete_session(session_id) when is_binary(session_id) do
    url = build_url("/authentication/session")
    body = %{session_id: session_id}

    case make_request(:delete, url, body) do
      {:ok, response_body} ->
        parse_delete_response(response_body)

      {:error, reason} ->
        Logger.error("Failed to delete session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def delete_session(_invalid_session_id) do
    {:error, :invalid_session_id}
  end

  @doc """
  Gets account details for a TMDB session.

  ## Parameters
  - `session_id`: The authenticated session ID

  ## Returns
  - `{:ok, account_details}` on success
  - `{:error, reason}` on failure

  ## Examples

      iex> Flixir.Auth.TMDBClient.get_account_details("session_123")
      {:ok, %{
        id: 12345,
        username: "user123",
        name: "John Doe",
        include_adult: false,
        iso_639_1: "en",
        iso_3166_1: "US",
        avatar: %{...}
      }}
  """
  def get_account_details(session_id) when is_binary(session_id) do
    url = build_url("/account", %{session_id: session_id})

    case make_request(:get, url) do
      {:ok, response_body} ->
        parse_account_response(response_body)

      {:error, reason} ->
        Logger.error(
          "Failed to get account details for session #{session_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def get_account_details(_invalid_session_id) do
    {:error, :invalid_session_id}
  end

  # Private functions

  defp make_request(method, url, body \\ nil) do
    options = [
      receive_timeout: get_timeout(),
      retry: :transient,
      max_retries: get_max_retries(),
      retry_delay: fn attempt -> :timer.seconds(2 ** attempt) end,
      headers: headers()
    ]

    options = if body, do: Keyword.put(options, :json, body), else: options

    case apply(Req, method, [url, options]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: 201, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: 401}} ->
        Logger.error("TMDB API authentication failed - check API key or session")
        {:error, :unauthorized}

      {:ok, %Req.Response{status: 404}} ->
        Logger.warning("TMDB resource not found: #{url}")
        {:error, :not_found}

      {:ok, %Req.Response{status: 429}} ->
        Logger.warning("TMDB API rate limit exceeded")
        {:error, :rate_limited}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("TMDB API returned unexpected status: #{status}, body: #{inspect(body)}")
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

  defp parse_token_response(%{
         "success" => true,
         "request_token" => token,
         "expires_at" => expires_at
       }) do
    {:ok,
     %{
       request_token: token,
       expires_at: expires_at
     }}
  end

  defp parse_token_response(%{"success" => false} = response) do
    Logger.error("TMDB token creation failed: #{inspect(response)}")
    {:error, :token_creation_failed}
  end

  defp parse_token_response(response) do
    Logger.error("Invalid token response format: #{inspect(response)}")
    {:error, :invalid_response_format}
  end

  defp parse_session_response(%{"success" => true, "session_id" => session_id}) do
    {:ok, %{session_id: session_id}}
  end

  defp parse_session_response(%{"success" => false} = response) do
    Logger.error("TMDB session creation failed: #{inspect(response)}")
    {:error, :session_creation_failed}
  end

  defp parse_session_response(response) do
    Logger.error("Invalid session response format: #{inspect(response)}")
    {:error, :invalid_response_format}
  end

  defp parse_delete_response(%{"success" => true}) do
    {:ok, %{success: true}}
  end

  defp parse_delete_response(%{"success" => false} = response) do
    Logger.error("TMDB session deletion failed: #{inspect(response)}")
    {:error, :session_deletion_failed}
  end

  defp parse_delete_response(response) do
    Logger.error("Invalid delete response format: #{inspect(response)}")
    {:error, :invalid_response_format}
  end

  defp parse_account_response(%{"id" => _id} = account_data) do
    {:ok, account_data}
  end

  defp parse_account_response(response) do
    Logger.error("Invalid account response format: #{inspect(response)}")
    {:error, :invalid_response_format}
  end

  defp build_url(path, params \\ %{}) do
    api_key = get_api_key()
    base_params = %{api_key: api_key}
    all_params = Map.merge(base_params, params)

    query_string = URI.encode_query(all_params)
    "#{@base_url}#{path}?#{query_string}"
  end

  defp headers do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "Flixir/1.0"}
    ]
  end

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
