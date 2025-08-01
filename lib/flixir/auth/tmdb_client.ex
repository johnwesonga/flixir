defmodule Flixir.Auth.TMDBClient do
  @moduledoc """
  HTTP client for TMDB authentication operations.

  Handles the three-step TMDB authentication flow:
  1. Request token creation
  2. Token validation with user credentials (handled by TMDB website)
  3. Session creation from approved token

  Also provides functions for session management and user account details.

  This module includes comprehensive error handling with retry logic,
  exponential backoff, and graceful degradation for TMDB API issues.
  """

  require Logger
  alias Flixir.Auth.ErrorHandler

  @default_timeout 10_000  # Increased timeout for better reliability

  @doc """
  Creates a new request token from TMDB API.

  This is the first step in the TMDB authentication flow. The returned token
  must be approved by the user on the TMDB website before it can be used to
  create a session.

  Includes automatic retry logic with exponential backoff for network errors
  and graceful handling of TMDB API unavailability.

  ## Returns
  - `{:ok, %{request_token: token, expires_at: datetime}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Auth.TMDBClient.create_request_token()
      {:ok, %{
        request_token: "abc123...",
        expires_at: "2024-01-01 12:00:00 UTC"
      }}
  """
  def create_request_token do
    context = %{
      operation: :create_request_token,
      attempt: 1,
      user_id: nil,
      session_id: nil,
      additional_info: %{}
    }

    make_request_with_retry(:get, "/authentication/token/new", nil, context, &parse_token_response/1)
  end

  @doc """
  Creates a session from an approved request token.

  This is the final step in the TMDB authentication flow. The token must have
  been approved by the user on the TMDB website.

  Includes automatic retry logic with exponential backoff for network errors
  and comprehensive error handling for authentication failures.

  ## Parameters
  - `request_token`: The approved request token from TMDB

  ## Returns
  - `{:ok, %{session_id: session_id}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Auth.TMDBClient.create_session("approved_token_123")
      {:ok, %{session_id: "session_abc123..."}}
  """
  def create_session(request_token) when is_binary(request_token) do
    context = %{
      operation: :create_session,
      attempt: 1,
      user_id: nil,
      session_id: nil,
      additional_info: %{request_token: request_token}
    }

    body = %{request_token: request_token}
    make_request_with_retry(:post, "/authentication/session/new", body, context, &parse_session_response/1)
  end

  def create_session(_invalid_token) do
    Logger.warning("Attempted to create session with invalid token format")
    {:error, :invalid_token}
  end

  @doc """
  Deletes/invalidates a TMDB session.

  Includes retry logic for network errors but gracefully handles cases
  where the session is already invalid or expired on TMDB's side.

  ## Parameters
  - `session_id`: The session ID to invalidate

  ## Returns
  - `{:ok, %{success: true}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Auth.TMDBClient.delete_session("session_123")
      {:ok, %{success: true}}
  """
  def delete_session(session_id) when is_binary(session_id) do
    context = %{
      operation: :delete_session,
      attempt: 1,
      user_id: nil,
      session_id: session_id,
      additional_info: %{}
    }

    body = %{session_id: session_id}
    make_request_with_retry(:delete, "/authentication/session", body, context, &parse_delete_response/1)
  end

  def delete_session(_invalid_session_id) do
    Logger.warning("Attempted to delete session with invalid session ID format")
    {:error, :invalid_session_id}
  end

  @doc """
  Gets account details for a TMDB session.

  Includes retry logic for network errors and comprehensive error handling
  for session validation issues.

  ## Parameters
  - `session_id`: The authenticated session ID

  ## Returns
  - `{:ok, account_details}` on success
  - `{:error, classified_error}` on failure

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
    context = %{
      operation: :get_account_details,
      attempt: 1,
      user_id: nil,
      session_id: session_id,
      additional_info: %{}
    }

    params = %{session_id: session_id}
    make_request_with_retry(:get, "/account", nil, context, &parse_account_response/1, params)
  end

  def get_account_details(_invalid_session_id) do
    Logger.warning("Attempted to get account details with invalid session ID format")
    {:error, :invalid_session_id}
  end

  # Private functions

  defp make_request_with_retry(method, path, body, context, parser, params \\ %{}) do
    url = build_url(path, params)

    case make_single_request(method, url, body, context) do
      {:ok, response_body} ->
        parser.(response_body)

      {:error, reason} ->
        error_result = ErrorHandler.handle_auth_error(reason, context)

        # Skip retries in test environment to prevent timeouts
        if should_retry_in_env?() and ErrorHandler.should_retry?(error_result, context.attempt) do
          delay = ErrorHandler.retry_delay(context.attempt, elem(error_result, 1))

          Logger.info("Retrying #{context.operation} after #{delay}ms", %{
            attempt: context.attempt,
            operation: context.operation,
            delay_ms: delay
          })

          :timer.sleep(delay)

          updated_context = %{context | attempt: context.attempt + 1}
          make_request_with_retry(method, path, body, updated_context, parser, params)
        else
          error_result
        end
    end
  end

  defp make_single_request(method, url, body, context) do
    options = [
      receive_timeout: get_timeout(),
      headers: headers()
    ]

    options = if body, do: Keyword.put(options, :json, body), else: options

    Logger.debug("Making TMDB API request", %{
      method: method,
      url: sanitize_url_for_logging(url),
      operation: context.operation,
      attempt: context.attempt
    })

    case apply(Req, method, [url, options]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        Logger.debug("TMDB API request successful", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 200
        })
        {:ok, body}

      {:ok, %Req.Response{status: 201, body: body}} ->
        Logger.debug("TMDB API request successful", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 201
        })
        {:ok, body}

      {:ok, %Req.Response{status: 401, body: body}} ->
        Logger.warning("TMDB API authentication failed", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 401,
          response_body: inspect(body)
        })
        {:error, :unauthorized}

      {:ok, %Req.Response{status: 404, body: body}} ->
        Logger.warning("TMDB resource not found", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 404,
          url: sanitize_url_for_logging(url),
          response_body: inspect(body)
        })
        {:error, :not_found}

      {:ok, %Req.Response{status: 429, body: body}} ->
        Logger.warning("TMDB API rate limit exceeded", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 429,
          response_body: inspect(body)
        })
        {:error, :rate_limited}

      {:ok, %Req.Response{status: status, body: body}} when status >= 500 ->
        Logger.error("TMDB API server error", %{
          operation: context.operation,
          attempt: context.attempt,
          status: status,
          response_body: inspect(body)
        })
        {:error, {:unexpected_status, status}}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("TMDB API unexpected status", %{
          operation: context.operation,
          attempt: context.attempt,
          status: status,
          response_body: inspect(body)
        })
        {:error, {:unexpected_status, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        Logger.warning("TMDB API request timed out", %{
          operation: context.operation,
          attempt: context.attempt,
          timeout_ms: get_timeout()
        })
        {:error, :timeout}

      {:error, %Req.TransportError{reason: reason}} ->
        Logger.error("TMDB API transport error", %{
          operation: context.operation,
          attempt: context.attempt,
          transport_error: inspect(reason)
        })
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        Logger.error("TMDB API request failed", %{
          operation: context.operation,
          attempt: context.attempt,
          error: inspect(reason)
        })
        {:error, reason}
    end
  end

  defp parse_token_response(%{
         "success" => true,
         "request_token" => token,
         "expires_at" => expires_at
       }) when is_binary(token) and is_binary(expires_at) do
    Logger.debug("Successfully parsed token response", %{
      token_length: String.length(token),
      expires_at: expires_at
    })

    {:ok,
     %{
       request_token: token,
       expires_at: expires_at
     }}
  end

  defp parse_token_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB token creation failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :token_creation_failed}
  end

  defp parse_token_response(%{"success" => false} = response) do
    Logger.error("TMDB token creation failed", %{
      response: inspect(response)
    })
    {:error, :token_creation_failed}
  end

  defp parse_token_response(response) do
    Logger.error("Invalid token response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_session_response(%{"success" => true, "session_id" => session_id}) when is_binary(session_id) do
    Logger.debug("Successfully parsed session response", %{
      session_id_length: String.length(session_id)
    })
    {:ok, %{session_id: session_id}}
  end

  defp parse_session_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB session creation failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :session_creation_failed}
  end

  defp parse_session_response(%{"success" => false} = response) do
    Logger.error("TMDB session creation failed", %{
      response: inspect(response)
    })
    {:error, :session_creation_failed}
  end

  defp parse_session_response(response) do
    Logger.error("Invalid session response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_delete_response(%{"success" => true}) do
    Logger.debug("Successfully parsed delete response")
    {:ok, %{success: true}}
  end

  defp parse_delete_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB session deletion failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :session_deletion_failed}
  end

  defp parse_delete_response(%{"success" => false} = response) do
    Logger.error("TMDB session deletion failed", %{
      response: inspect(response)
    })
    {:error, :session_deletion_failed}
  end

  defp parse_delete_response(response) do
    Logger.error("Invalid delete response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_account_response(%{"id" => id, "username" => username} = account_data)
    when is_integer(id) and is_binary(username) do
    Logger.debug("Successfully parsed account response", %{
      user_id: id,
      username: username
    })
    {:ok, account_data}
  end

  defp parse_account_response(%{"status_message" => message} = response) do
    Logger.error("TMDB account details request failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_account_response(response) do
    Logger.error("Invalid account response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp build_url(path, params) do
    base_url = get_base_url()
    api_key = get_api_key()
    base_params = %{api_key: api_key}
    all_params = Map.merge(base_params, params)

    query_string = URI.encode_query(all_params)
    "#{base_url}#{path}?#{query_string}"
  end

  defp headers do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "Flixir/1.0"}
    ]
  end

  defp get_base_url do
    Application.get_env(:flixir, :tmdb)[:base_url] || "https://api.themoviedb.org/3"
  end

  defp sanitize_url_for_logging(url) do
    # Remove API key from URL for logging
    String.replace(url, ~r/api_key=[^&]+/, "api_key=***")
  end

  defp get_api_key do
    case Application.get_env(:flixir, :tmdb)[:api_key] do
      nil ->
        Logger.error("TMDB API key not configured - check TMDB_API_KEY environment variable")
        raise "TMDB API key not found. Please set TMDB_API_KEY environment variable."

      api_key when is_binary(api_key) and byte_size(api_key) > 10 ->
        api_key

      api_key when is_binary(api_key) ->
        Logger.error("TMDB API key appears to be invalid", %{
          key_length: byte_size(api_key)
        })
        raise "Invalid TMDB API key - key appears too short"

      _ ->
        Logger.error("Invalid TMDB API key configuration - must be a string")
        raise "Invalid TMDB API key configuration"
    end
  end

  defp get_timeout do
    Application.get_env(:flixir, :tmdb)[:timeout] || @default_timeout
  end

  defp should_retry_in_env? do
    # Disable retries in test environment to prevent test timeouts
    Mix.env() != :test
  end
end
