defmodule Flixir.Auth.ErrorHandler do
  @moduledoc """
  Handles authentication errors with fallback strategies and user-friendly error messages.

  This module provides comprehensive error handling for TMDB authentication operations,
  including retry logic, exponential backoff, and user-friendly error formatting.
  """

  require Logger

  @type error_context :: %{
    operation: atom(),
    attempt: integer(),
    user_id: String.t() | nil,
    session_id: String.t() | nil,
    additional_info: map()
  }

  @type auth_error ::
    :network_error
    | :rate_limited
    | :service_unavailable
    | :authentication_failed
    | :session_expired
    | :invalid_credentials
    | :token_expired
    | :api_key_invalid
    | :unknown

  @type error_result :: {:error, auth_error()}

  @doc """
  Handle authentication API errors with appropriate fallback strategies.

  ## Parameters
  - `error` - The original error from the API call
  - `context` - Context information about the operation

  ## Returns
  - `{:error, classified_error}` - Classified error for consistent handling

  ## Examples

      iex> handle_auth_error(:timeout, %{operation: :create_token, attempt: 1})
      {:error, :network_error}

      iex> handle_auth_error({:unexpected_status, 429}, %{operation: :create_session, attempt: 2})
      {:error, :rate_limited}
  """
  @spec handle_auth_error(any(), error_context()) :: error_result()
  def handle_auth_error(error, context) do
    classified_error = classify_auth_error(error)

    log_auth_error(error, classified_error, context)

    case classified_error do
      :network_error -> handle_network_error(error, context)
      :rate_limited -> handle_rate_limit_error(error, context)
      :service_unavailable -> handle_service_error(error, context)
      :authentication_failed -> handle_auth_failure(error, context)
      :session_expired -> handle_session_expired(error, context)
      :invalid_credentials -> handle_invalid_credentials(error, context)
      :token_expired -> handle_token_expired(error, context)
      :api_key_invalid -> handle_api_key_error(error, context)
      :unknown -> handle_unknown_error(error, context)
    end
  end

  @doc """
  Determine if an authentication operation should be retried.

  ## Parameters
  - `error_result` - The classified error result
  - `attempt` - Current attempt number

  ## Returns
  - `boolean()` - Whether the operation should be retried
  """
  @spec should_retry?(error_result(), integer()) :: boolean()
  def should_retry?({:error, error_type}, attempt) when attempt < 3 do
    case error_type do
      :network_error -> true
      :service_unavailable -> true
      :rate_limited -> true
      :authentication_failed -> false
      :session_expired -> false
      :invalid_credentials -> false
      :token_expired -> false
      :api_key_invalid -> false
      :unknown -> true
    end
  end
  def should_retry?(_, _), do: false

  @doc """
  Calculate retry delay with exponential backoff.

  ## Parameters
  - `attempt` - Current attempt number
  - `error_type` - Type of error for custom delay logic

  ## Returns
  - `integer()` - Delay in milliseconds
  """
  @spec retry_delay(integer(), auth_error()) :: integer()
  def retry_delay(attempt, error_type) when attempt <= 3 do
    base_delay = case error_type do
      :rate_limited -> :timer.seconds(30)  # Longer delay for rate limits
      :network_error -> :timer.seconds(1)
      :service_unavailable -> :timer.seconds(5)
      _ -> :timer.seconds(2)
    end

    # Exponential backoff with jitter
    backoff_multiplier = Integer.pow(2, attempt - 1)
    jitter = :rand.uniform(1000)  # Add up to 1 second of jitter

    base_delay * backoff_multiplier + jitter
  end
  def retry_delay(_, :rate_limited), do: :timer.seconds(60)  # Long delay for high attempts with rate limiting
  def retry_delay(_, _), do: :timer.seconds(10)

  @doc """
  Generate user-friendly error messages for authentication failures.

  ## Parameters
  - `error_result` - The classified error result

  ## Returns
  - `String.t()` - User-friendly error message
  """
  @spec format_user_error(error_result()) :: String.t()
  def format_user_error({:error, error_type}) do
    case error_type do
      :network_error ->
        "Unable to connect to TMDB for authentication. Please check your internet connection and try again."

      :rate_limited ->
        "Too many authentication attempts. Please wait a moment and try again."

      :service_unavailable ->
        "TMDB authentication service is temporarily unavailable. Please try again in a few minutes."

      :authentication_failed ->
        "Authentication failed. Please check your TMDB credentials and try again."

      :session_expired ->
        "Your session has expired. Please log in again."

      :invalid_credentials ->
        "Invalid TMDB credentials. Please check your username and password."

      :token_expired ->
        "Authentication token has expired. Please try logging in again."

      :api_key_invalid ->
        "Authentication service configuration error. Please contact support."

      :unknown ->
        "An unexpected error occurred during authentication. Please try again."
    end
  end

  @doc """
  Generate technical error messages for logging and debugging.

  ## Parameters
  - `error_result` - The classified error result
  - `original_error` - The original error for technical details

  ## Returns
  - `String.t()` - Technical error message
  """
  @spec format_technical_error(error_result(), any()) :: String.t()
  def format_technical_error({:error, error_type}, original_error) do
    base_message = case error_type do
      :network_error -> "Network connectivity issue"
      :rate_limited -> "API rate limit exceeded"
      :service_unavailable -> "TMDB service unavailable"
      :authentication_failed -> "TMDB authentication rejected"
      :session_expired -> "Session validation failed"
      :invalid_credentials -> "Credential validation failed"
      :token_expired -> "Token validation failed"
      :api_key_invalid -> "API key validation failed"
      :unknown -> "Unclassified error"
    end

    "#{base_message}: #{inspect(original_error)}"
  end

  @doc """
  Check if an error indicates TMDB API unavailability.

  ## Parameters
  - `error_result` - The classified error result

  ## Returns
  - `boolean()` - Whether TMDB API is unavailable
  """
  @spec api_unavailable?(error_result()) :: boolean()
  def api_unavailable?({:error, error_type}) do
    case error_type do
      :network_error -> true
      :service_unavailable -> true
      :unknown -> true  # Conservative approach
      _ -> false
    end
  end

  @doc """
  Get structured error information for telemetry and monitoring.

  ## Parameters
  - `error_result` - The classified error result
  - `context` - Error context information

  ## Returns
  - `map()` - Structured error information
  """
  @spec error_telemetry(error_result(), error_context()) :: map()
  def error_telemetry({:error, error_type}, context) do
    %{
      error_type: error_type,
      operation: context.operation,
      attempt: context.attempt,
      retryable: should_retry?({:error, error_type}, context.attempt),
      user_id: context.user_id,
      session_id: context.session_id,
      timestamp: DateTime.utc_now(),
      additional_info: context.additional_info
    }
  end

  # Private functions

  @spec classify_auth_error(any()) :: auth_error()
  defp classify_auth_error(%Req.TransportError{reason: :timeout}), do: :network_error
  defp classify_auth_error(%Req.TransportError{reason: :econnrefused}), do: :network_error
  defp classify_auth_error(%Req.TransportError{reason: :nxdomain}), do: :network_error
  defp classify_auth_error(%Req.TransportError{}), do: :network_error
  defp classify_auth_error(:timeout), do: :network_error
  defp classify_auth_error(:rate_limited), do: :rate_limited
  defp classify_auth_error(:unauthorized), do: :authentication_failed
  defp classify_auth_error(:not_found), do: :service_unavailable
  defp classify_auth_error(:token_creation_failed), do: :authentication_failed
  defp classify_auth_error(:session_creation_failed), do: :authentication_failed
  defp classify_auth_error(:session_deletion_failed), do: :authentication_failed
  defp classify_auth_error(:invalid_response_format), do: :service_unavailable
  defp classify_auth_error(:invalid_token), do: :token_expired
  defp classify_auth_error(:invalid_session_id), do: :session_expired
  defp classify_auth_error(:session_expired), do: :session_expired
  defp classify_auth_error({:transport_error, _}), do: :network_error
  defp classify_auth_error({:unexpected_status, status}) when status >= 500, do: :service_unavailable
  defp classify_auth_error({:unexpected_status, 401}), do: :authentication_failed
  defp classify_auth_error({:unexpected_status, 403}), do: :api_key_invalid
  defp classify_auth_error({:unexpected_status, 429}), do: :rate_limited
  defp classify_auth_error({:unexpected_status, _}), do: :unknown
  defp classify_auth_error(_), do: :unknown

  defp log_auth_error(original_error, classified_error, context) do
    log_level = case classified_error do
      :network_error when context.attempt < 3 -> :info
      :rate_limited -> :warning
      :authentication_failed -> :warning
      :session_expired -> :info
      :invalid_credentials -> :warning
      :token_expired -> :info
      :api_key_invalid -> :error
      _ -> :error
    end

    log_message = "Authentication error in #{context.operation}"

    log_metadata = %{
      error_type: classified_error,
      original_error: inspect(original_error),
      attempt: context.attempt,
      operation: context.operation,
      user_id: context.user_id,
      session_id: context.session_id,
      additional_info: context.additional_info
    }

    Logger.log(log_level, log_message, log_metadata)
  end

  defp handle_network_error(_error, context) do
    if context.attempt < 3 do
      Logger.info("Network error during #{context.operation}, will retry", %{
        attempt: context.attempt,
        operation: context.operation
      })
    end
    {:error, :network_error}
  end

  defp handle_rate_limit_error(_error, context) do
    Logger.warning("Rate limited during #{context.operation}", %{
      attempt: context.attempt,
      operation: context.operation,
      user_id: context.user_id
    })
    {:error, :rate_limited}
  end

  defp handle_service_error(error, context) do
    Logger.error("TMDB service unavailable during #{context.operation}", %{
      error: inspect(error),
      attempt: context.attempt,
      operation: context.operation
    })
    {:error, :service_unavailable}
  end

  defp handle_auth_failure(error, context) do
    Logger.warning("Authentication failed during #{context.operation}", %{
      error: inspect(error),
      operation: context.operation,
      user_id: context.user_id
    })
    {:error, :authentication_failed}
  end

  defp handle_session_expired(_error, context) do
    Logger.info("Session expired during #{context.operation}", %{
      operation: context.operation,
      session_id: context.session_id,
      user_id: context.user_id
    })
    {:error, :session_expired}
  end

  defp handle_invalid_credentials(error, context) do
    Logger.warning("Invalid credentials during #{context.operation}", %{
      error: inspect(error),
      operation: context.operation
    })
    {:error, :invalid_credentials}
  end

  defp handle_token_expired(_error, context) do
    Logger.info("Token expired during #{context.operation}", %{
      operation: context.operation
    })
    {:error, :token_expired}
  end

  defp handle_api_key_error(error, context) do
    Logger.error("API key invalid during #{context.operation}", %{
      error: inspect(error),
      operation: context.operation
    })
    {:error, :api_key_invalid}
  end

  defp handle_unknown_error(error, context) do
    Logger.error("Unknown error during #{context.operation}", %{
      error: inspect(error),
      operation: context.operation,
      attempt: context.attempt,
      user_id: context.user_id,
      session_id: context.session_id
    })
    {:error, :unknown}
  end
end
