defmodule Flixir.Reviews.ErrorHandlerTest do
  use ExUnit.Case, async: true
  alias Flixir.Reviews.ErrorHandler

  describe "handle_api_error/2" do
    test "handles network errors" do
      error = %Req.TransportError{reason: :econnrefused}
      context = %{media_type: "movie", media_id: "123", operation: :get_reviews, attempt: 1}

      result = ErrorHandler.handle_api_error(error, context)
      assert {:error, :network_error} = result
    end

    test "handles rate limit errors" do
      error = :rate_limited
      context = %{media_type: "movie", media_id: "123", operation: :get_reviews, attempt: 1}

      result = ErrorHandler.handle_api_error(error, context)
      assert {:error, :rate_limited} = result
    end

    test "handles not found errors" do
      error = :not_found
      context = %{media_type: "movie", media_id: "123", operation: :get_reviews, attempt: 1}

      result = ErrorHandler.handle_api_error(error, context)
      assert {:error, :not_found} = result
    end

    test "handles service unavailable errors" do
      error = {:unexpected_status, 503}
      context = %{media_type: "movie", media_id: "123", operation: :get_reviews, attempt: 1}

      result = ErrorHandler.handle_api_error(error, context)
      assert {:error, :service_unavailable} = result
    end

    test "handles timeout errors" do
      error = {:error, :timeout}
      context = %{media_type: "movie", media_id: "123", operation: :get_reviews, attempt: 1}

      result = ErrorHandler.handle_api_error(error, context)
      assert {:error, :network_error} = result
    end

    test "handles unknown errors" do
      error = {:error, :some_unknown_error}
      context = %{media_type: "movie", media_id: "123", operation: :get_reviews, attempt: 1}

      result = ErrorHandler.handle_api_error(error, context)
      assert {:error, :unknown} = result
    end
  end

  describe "use_cached_fallback?/1" do
    test "returns true for network errors" do
      assert ErrorHandler.use_cached_fallback?({:error, :network_error}) == true
    end

    test "returns true for service unavailable errors" do
      assert ErrorHandler.use_cached_fallback?({:error, :service_unavailable}) == true
    end

    test "returns true for rate limited errors" do
      assert ErrorHandler.use_cached_fallback?({:error, :rate_limited}) == true
    end

    test "returns false for not found errors" do
      assert ErrorHandler.use_cached_fallback?({:error, :not_found}) == false
    end

    test "returns true for unknown errors" do
      assert ErrorHandler.use_cached_fallback?({:error, :unknown}) == true
    end
  end

  describe "format_user_error/1" do
    test "formats network error message" do
      message = ErrorHandler.format_user_error({:error, :network_error})
      assert message =~ "connection issues"
      assert message =~ "internet connection"
    end

    test "formats rate limited error message" do
      message = ErrorHandler.format_user_error({:error, :rate_limited})
      assert message =~ "Too many requests"
      assert message =~ "wait a moment"
    end

    test "formats not found error message" do
      message = ErrorHandler.format_user_error({:error, :not_found})
      assert message =~ "No reviews found"
    end

    test "formats service unavailable error message" do
      message = ErrorHandler.format_user_error({:error, :service_unavailable})
      assert message =~ "temporarily unavailable"
      assert message =~ "try again later"
    end

    test "formats unknown error message" do
      message = ErrorHandler.format_user_error({:error, :unknown})
      assert message =~ "Something went wrong"
      assert message =~ "try again"
    end
  end

  describe "retryable?/1" do
    test "returns true for retryable errors" do
      assert ErrorHandler.retryable?({:error, :network_error}) == true
      assert ErrorHandler.retryable?({:error, :service_unavailable}) == true
      assert ErrorHandler.retryable?({:error, :rate_limited}) == true
      assert ErrorHandler.retryable?({:error, :unknown}) == true
    end

    test "returns false for non-retryable errors" do
      assert ErrorHandler.retryable?({:error, :not_found}) == false
    end
  end

  describe "retry_delay/1" do
    test "returns exponential backoff delays" do
      assert ErrorHandler.retry_delay(1) == 1000  # 1 second
      assert ErrorHandler.retry_delay(2) == 2000  # 2 seconds
      assert ErrorHandler.retry_delay(3) == 4000  # 4 seconds
    end

    test "caps delay at 8 seconds for high attempt numbers" do
      assert ErrorHandler.retry_delay(4) == 8000
      assert ErrorHandler.retry_delay(10) == 8000
    end
  end
end
