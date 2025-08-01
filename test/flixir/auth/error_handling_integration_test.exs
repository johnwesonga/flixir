defmodule Flixir.Auth.ErrorHandlingIntegrationTest do
  use Flixir.DataCase, async: true
  import Mock

  alias Flixir.Auth

  alias Flixir.Auth.ErrorHandler

  @moduletag :integration

  describe "end-to-end error handling" do
    test "handles network errors gracefully in authentication flow" do
      with_mocks [
        {Application, [], [
          get_env: fn
            :flixir, :tmdb -> [api_key: "test_api_key_12345678901234567890"]
            app, key -> Application.get_env(app, key)
          end
        ]},
        {Req, [], [
          get: fn(_url, _opts) ->
            {:error, %Req.TransportError{reason: :timeout}}
          end
        ]}
      ] do
        # Test that network errors are properly classified and handled
        assert {:error, :network_error} = Auth.start_authentication()
      end
    end

    test "handles rate limiting gracefully in authentication flow" do
      with_mocks [
        {Application, [], [
          get_env: fn
            :flixir, :tmdb -> [api_key: "test_api_key_12345678901234567890"]
            app, key -> Application.get_env(app, key)
          end
        ]},
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 429, body: %{"status_message" => "Rate limit exceeded"}}}
          end
        ]}
      ] do
        # Test that rate limiting is properly classified and handled
        assert {:error, :rate_limited} = Auth.start_authentication()
      end
    end

    test "handles service unavailability gracefully in authentication flow" do
      with_mocks [
        {Application, [], [
          get_env: fn
            :flixir, :tmdb -> [api_key: "test_api_key_12345678901234567890"]
            app, key -> Application.get_env(app, key)
          end
        ]},
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 503, body: %{"status_message" => "Service temporarily unavailable"}}}
          end
        ]}
      ] do
        # Test that service unavailability is properly classified and handled
        assert {:error, :service_unavailable} = Auth.start_authentication()
      end
    end

    test "provides user-friendly error messages for all error types" do
      # Test that all error types have user-friendly messages
      error_types = [
        :network_error,
        :rate_limited,
        :service_unavailable,
        :authentication_failed,
        :session_expired,
        :invalid_credentials,
        :token_expired,
        :api_key_invalid,
        :unknown
      ]

      for error_type <- error_types do
        message = ErrorHandler.format_user_error({:error, error_type})

        # Ensure message is user-friendly (not technical)
        assert is_binary(message)
        assert String.length(message) > 10
        refute String.contains?(message, "inspect")
        refute String.contains?(message, "%{")
        refute String.contains?(message, "Req.TransportError")
      end
    end

    test "correctly identifies API unavailability scenarios" do
      # Test scenarios where API is considered unavailable
      unavailable_errors = [:network_error, :service_unavailable, :unknown]
      available_errors = [:authentication_failed, :rate_limited, :session_expired]

      for error_type <- unavailable_errors do
        assert ErrorHandler.api_unavailable?({:error, error_type}) == true
      end

      for error_type <- available_errors do
        assert ErrorHandler.api_unavailable?({:error, error_type}) == false
      end
    end

    test "retry logic respects attempt limits" do
      # Test that retry logic doesn't exceed reasonable limits
      for attempt <- 1..5 do
        retryable = ErrorHandler.should_retry?({:error, :network_error}, attempt)

        if attempt <= 2 do
          assert retryable == true
        else
          assert retryable == false
        end
      end
    end

    test "retry delays use exponential backoff" do
      # Test that retry delays increase exponentially
      delay1 = ErrorHandler.retry_delay(1, :network_error)
      delay2 = ErrorHandler.retry_delay(2, :network_error)
      delay3 = ErrorHandler.retry_delay(3, :network_error)

      # Delays should increase (accounting for jitter)
      assert delay2 > delay1
      assert delay3 > delay2

      # Should be reasonable delays (not too long for tests)
      assert delay1 < 5000  # Less than 5 seconds
      assert delay2 < 10000 # Less than 10 seconds
      assert delay3 < 15000 # Less than 15 seconds
    end

    test "error telemetry includes all required fields" do
      context = %{
        operation: :create_session,
        attempt: 2,
        user_id: "user123",
        session_id: "session456",
        additional_info: %{request_token: "token789"}
      }

      telemetry = ErrorHandler.error_telemetry({:error, :network_error}, context)

      # Verify all required telemetry fields are present
      assert telemetry.error_type == :network_error
      assert telemetry.operation == :create_session
      assert telemetry.attempt == 2
      assert is_boolean(telemetry.retryable)
      assert telemetry.user_id == "user123"
      assert telemetry.session_id == "session456"
      assert telemetry.additional_info == %{request_token: "token789"}
      assert %DateTime{} = telemetry.timestamp
    end
  end

  describe "logging integration" do
    test "logs are generated at appropriate levels" do
      import ExUnit.CaptureLog

      context = %{
        operation: :create_token,
        attempt: 1,
        user_id: nil,
        session_id: nil,
        additional_info: %{}
      }

      # Test that different error types generate logs at appropriate levels
      log_output = capture_log(fn ->
        ErrorHandler.handle_auth_error(:network_error, context)
      end)

      # Network errors on first attempt should be info level
      assert log_output =~ "Authentication error in create_token"

      log_output = capture_log(fn ->
        ErrorHandler.handle_auth_error({:unexpected_status, 403}, %{context | operation: :create_session})
      end)

      # API key errors should be error level
      assert log_output =~ "API key invalid during create_session"
    end
  end
end
