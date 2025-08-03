defmodule Flixir.Auth.ErrorHandlerTest do
  use ExUnit.Case, async: true

  alias Flixir.Auth.ErrorHandler

  describe "handle_auth_error/2" do
    test "classifies network errors correctly" do
      context = %{
        operation: :create_token,
        attempt: 1,
        user_id: nil,
        session_id: nil,
        additional_info: %{}
      }

      assert {:error, :network_error} = ErrorHandler.handle_auth_error(:timeout, context)
      assert {:error, :network_error} = ErrorHandler.handle_auth_error(%Req.TransportError{reason: :timeout}, context)
      assert {:error, :network_error} = ErrorHandler.handle_auth_error(%Req.TransportError{reason: :econnrefused}, context)
      assert {:error, :network_error} = ErrorHandler.handle_auth_error({:transport_error, :nxdomain}, context)
    end

    test "classifies rate limiting errors correctly" do
      context = %{
        operation: :create_session,
        attempt: 2,
        user_id: nil,
        session_id: nil,
        additional_info: %{}
      }

      assert {:error, :rate_limited} = ErrorHandler.handle_auth_error(:rate_limited, context)
      assert {:error, :rate_limited} = ErrorHandler.handle_auth_error({:unexpected_status, 429}, context)
    end

    test "classifies authentication errors correctly" do
      context = %{
        operation: :create_session,
        attempt: 1,
        user_id: nil,
        session_id: nil,
        additional_info: %{}
      }

      assert {:error, :authentication_failed} = ErrorHandler.handle_auth_error(:unauthorized, context)
      assert {:error, :authentication_failed} = ErrorHandler.handle_auth_error(:token_creation_failed, context)
      assert {:error, :authentication_failed} = ErrorHandler.handle_auth_error(:session_creation_failed, context)
      assert {:error, :authentication_failed} = ErrorHandler.handle_auth_error({:unexpected_status, 401}, context)
    end

    test "classifies service errors correctly" do
      context = %{
        operation: :get_account_details,
        attempt: 1,
        user_id: nil,
        session_id: "session123",
        additional_info: %{}
      }

      assert {:error, :service_unavailable} = ErrorHandler.handle_auth_error(:not_found, context)
      assert {:error, :service_unavailable} = ErrorHandler.handle_auth_error({:unexpected_status, 500}, context)
      assert {:error, :service_unavailable} = ErrorHandler.handle_auth_error({:unexpected_status, 503}, context)
      assert {:error, :service_unavailable} = ErrorHandler.handle_auth_error(:invalid_response_format, context)
    end

    test "classifies session errors correctly" do
      context = %{
        operation: :validate_session,
        attempt: 1,
        user_id: "user123",
        session_id: "session123",
        additional_info: %{}
      }

      assert {:error, :session_expired} = ErrorHandler.handle_auth_error(:session_expired, context)
      assert {:error, :session_expired} = ErrorHandler.handle_auth_error(:invalid_session_id, context)
      assert {:error, :token_expired} = ErrorHandler.handle_auth_error(:invalid_token, context)
    end

    test "classifies API key errors correctly" do
      context = %{
        operation: :create_token,
        attempt: 1,
        user_id: nil,
        session_id: nil,
        additional_info: %{}
      }

      assert {:error, :api_key_invalid} = ErrorHandler.handle_auth_error({:unexpected_status, 403}, context)
    end

    test "classifies unknown errors correctly" do
      context = %{
        operation: :unknown_operation,
        attempt: 1,
        user_id: nil,
        session_id: nil,
        additional_info: %{}
      }

      assert {:error, :unknown} = ErrorHandler.handle_auth_error(:some_random_error, context)
      assert {:error, :unknown} = ErrorHandler.handle_auth_error({:unexpected_status, 418}, context)
    end
  end

  describe "should_retry?/2" do
    test "allows retry for retryable errors within attempt limit" do
      assert ErrorHandler.should_retry?({:error, :network_error}, 1) == true
      assert ErrorHandler.should_retry?({:error, :network_error}, 2) == true
      assert ErrorHandler.should_retry?({:error, :network_error}, 3) == false
      assert ErrorHandler.should_retry?({:error, :network_error}, 4) == false

      assert ErrorHandler.should_retry?({:error, :service_unavailable}, 1) == true
      assert ErrorHandler.should_retry?({:error, :service_unavailable}, 2) == true
      assert ErrorHandler.should_retry?({:error, :service_unavailable}, 3) == false

      assert ErrorHandler.should_retry?({:error, :rate_limited}, 1) == true
      assert ErrorHandler.should_retry?({:error, :rate_limited}, 2) == true
      assert ErrorHandler.should_retry?({:error, :rate_limited}, 3) == false

      assert ErrorHandler.should_retry?({:error, :unknown}, 1) == true
      assert ErrorHandler.should_retry?({:error, :unknown}, 2) == true
      assert ErrorHandler.should_retry?({:error, :unknown}, 3) == false
    end

    test "does not allow retry for non-retryable errors" do
      assert ErrorHandler.should_retry?({:error, :authentication_failed}, 1) == false
      assert ErrorHandler.should_retry?({:error, :session_expired}, 1) == false
      assert ErrorHandler.should_retry?({:error, :invalid_credentials}, 1) == false
      assert ErrorHandler.should_retry?({:error, :token_expired}, 1) == false
      assert ErrorHandler.should_retry?({:error, :api_key_invalid}, 1) == false
    end
  end

  describe "retry_delay/2" do
    test "calculates exponential backoff with jitter" do
      # Test that delays increase exponentially (within jitter range)
      delay1 = ErrorHandler.retry_delay(1, :network_error)
      delay2 = ErrorHandler.retry_delay(2, :network_error)
      delay3 = ErrorHandler.retry_delay(3, :network_error)

      # Base delays should be roughly: 1s, 2s, 4s (plus jitter)
      assert delay1 >= 1000 and delay1 <= 2000
      assert delay2 >= 2000 and delay2 <= 3000
      assert delay3 >= 4000 and delay3 <= 5000
    end

    test "uses longer delays for rate limiting" do
      delay = ErrorHandler.retry_delay(1, :rate_limited)
      assert delay >= 30000  # At least 30 seconds for rate limiting
    end

    test "caps delays for high attempt numbers" do
      delay = ErrorHandler.retry_delay(5, :network_error)
      assert delay == 10000  # 10 seconds max

      delay_rate_limited = ErrorHandler.retry_delay(5, :rate_limited)
      assert delay_rate_limited == 60000  # 60 seconds for rate limited
    end
  end

  describe "format_user_error/1" do
    test "provides user-friendly messages for all error types" do
      assert ErrorHandler.format_user_error({:error, :network_error}) =~ "Network error during authentication"
      assert ErrorHandler.format_user_error({:error, :rate_limited}) =~ "Too many authentication attempts"
      assert ErrorHandler.format_user_error({:error, :service_unavailable}) =~ "Authentication service not found"
      assert ErrorHandler.format_user_error({:error, :authentication_failed}) =~ "Authentication failed"
      assert ErrorHandler.format_user_error({:error, :session_expired}) =~ "session has expired"
      assert ErrorHandler.format_user_error({:error, :invalid_credentials}) =~ "Invalid TMDB credentials"
      assert ErrorHandler.format_user_error({:error, :token_expired}) =~ "token has expired"
      assert ErrorHandler.format_user_error({:error, :api_key_invalid}) =~ "configuration error"
      assert ErrorHandler.format_user_error({:error, :unknown}) =~ "unexpected error"
    end
  end

  describe "format_technical_error/2" do
    test "provides technical details for debugging" do
      original_error = %Req.TransportError{reason: :timeout}
      result = ErrorHandler.format_technical_error({:error, :network_error}, original_error)

      assert result =~ "Network connectivity issue"
      assert result =~ inspect(original_error)
    end
  end

  describe "api_unavailable?/1" do
    test "correctly identifies API unavailability" do
      assert ErrorHandler.api_unavailable?({:error, :network_error}) == true
      assert ErrorHandler.api_unavailable?({:error, :service_unavailable}) == true
      assert ErrorHandler.api_unavailable?({:error, :unknown}) == true

      assert ErrorHandler.api_unavailable?({:error, :authentication_failed}) == false
      assert ErrorHandler.api_unavailable?({:error, :rate_limited}) == false
      assert ErrorHandler.api_unavailable?({:error, :session_expired}) == false
    end
  end

  describe "error_telemetry/2" do
    test "generates structured telemetry data" do
      context = %{
        operation: :create_session,
        attempt: 2,
        user_id: "user123",
        session_id: "session456",
        additional_info: %{request_token: "token789"}
      }

      telemetry = ErrorHandler.error_telemetry({:error, :network_error}, context)

      assert telemetry.error_type == :network_error
      assert telemetry.operation == :create_session
      assert telemetry.attempt == 2
      assert telemetry.retryable == true
      assert telemetry.user_id == "user123"
      assert telemetry.session_id == "session456"
      assert telemetry.additional_info == %{request_token: "token789"}
      assert %DateTime{} = telemetry.timestamp
    end
  end
end
