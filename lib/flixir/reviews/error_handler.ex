defmodule Flixir.Reviews.ErrorHandler do
  @moduledoc """
  Handles API errors with fallback strategies and user-friendly error messages.
  """

  require Logger

  @type error_context :: %{
    media_type: String.t(),
    media_id: String.t(),
    operation: atom(),
    attempt: integer()
  }

  @type error_result :: {:error, :network_error | :rate_limited | :not_found | :service_unavailable | :unknown}

  @doc """
  Handle API errors with appropriate fallback strategies.
  """
  @spec handle_api_error(any(), error_context()) :: error_result()
  def handle_api_error(error, context) do
    Logger.error("API error in #{context.operation}", %{
      error: inspect(error),
      context: context
    })

    case classify_error(error) do
      :network_error -> handle_network_error(error, context)
      :rate_limited -> handle_rate_limit_error(error, context)
      :not_found -> handle_not_found_error(error, context)
      :service_unavailable -> handle_service_error(error, context)
      :unknown -> handle_unknown_error(error, context)
    end
  end

  @doc """
  Determine if cached data should be used as fallback.
  """
  @spec use_cached_fallback?(error_result()) :: boolean()
  def use_cached_fallback?({:error, error_type}) do
    case error_type do
      :network_error -> true
      :service_unavailable -> true
      :rate_limited -> true
      :not_found -> false
      :unknown -> true
    end
  end

  @doc """
  Generate user-friendly error messages.
  """
  @spec format_user_error(error_result()) :: String.t()
  def format_user_error({:error, error_type}) do
    case error_type do
      :network_error ->
        "Unable to load reviews due to connection issues. Please check your internet connection and try again."

      :rate_limited ->
        "Too many requests. Please wait a moment before trying again."

      :not_found ->
        "No reviews found for this content."

      :service_unavailable ->
        "The review service is temporarily unavailable. Please try again later."

      :unknown ->
        "Something went wrong while loading reviews. Please try again."
    end
  end

  @doc """
  Check if an error is retryable.
  """
  @spec retryable?(error_result()) :: boolean()
  def retryable?({:error, error_type}) do
    case error_type do
      :network_error -> true
      :service_unavailable -> true
      :rate_limited -> true
      :not_found -> false
      :unknown -> true
    end
  end

  @doc """
  Get retry delay in milliseconds based on attempt number.
  """
  @spec retry_delay(integer()) :: integer()
  def retry_delay(attempt) when attempt <= 3 do
    # Exponential backoff: 1s, 2s, 4s
    :timer.seconds(Integer.pow(2, attempt - 1))
  end
  def retry_delay(_), do: :timer.seconds(8)

  # Private functions

  defp classify_error(%Req.TransportError{}), do: :network_error
  defp classify_error(:rate_limited), do: :rate_limited
  defp classify_error(:not_found), do: :not_found
  defp classify_error(:timeout), do: :network_error
  defp classify_error(:unauthorized), do: :service_unavailable
  defp classify_error({:unexpected_status, status}) when status >= 500, do: :service_unavailable
  defp classify_error({:transport_error, _}), do: :network_error
  defp classify_error({:error, :timeout}), do: :network_error
  defp classify_error({:error, :econnrefused}), do: :network_error
  defp classify_error({:error, :nxdomain}), do: :network_error
  defp classify_error(_), do: :unknown

  defp handle_network_error(_error, context) do
    if context.attempt < 3 do
      Logger.info("Network error, will retry", %{attempt: context.attempt, context: context})
    end
    {:error, :network_error}
  end

  defp handle_rate_limit_error(_error, context) do
    Logger.warning("Rate limited", %{context: context})
    {:error, :rate_limited}
  end

  defp handle_not_found_error(_error, context) do
    Logger.info("Resource not found", %{context: context})
    {:error, :not_found}
  end

  defp handle_service_error(error, context) do
    Logger.error("Service unavailable", %{error: inspect(error), context: context})
    {:error, :service_unavailable}
  end

  defp handle_unknown_error(error, context) do
    Logger.error("Unknown error", %{error: inspect(error), context: context})
    {:error, :unknown}
  end
end
