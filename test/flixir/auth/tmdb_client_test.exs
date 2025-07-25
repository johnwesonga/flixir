defmodule Flixir.Auth.TMDBClientTest do
  use ExUnit.Case, async: true
  import Mock

  alias Flixir.Auth.TMDBClient

  # Mock configuration helper
  defp mock_config do
    [
      {Application, [], [
        get_env: fn
          :flixir, :tmdb -> [
            api_key: "test_api_key",
            timeout: 5_000,
            max_retries: 3
          ]
        end
      ]}
    ]
  end

  describe "create_request_token/0" do
    test "successfully creates request token" do
      mock_response = %{
        "success" => true,
        "expires_at" => "2024-01-01 12:00:00 UTC",
        "request_token" => "test_token_123"
      }

      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:ok, result} = TMDBClient.create_request_token()

        assert %{
          request_token: "test_token_123",
          expires_at: "2024-01-01 12:00:00 UTC"
        } = result

        # Verify the correct URL was called
        assert_called Req.get(:_, :_)
      end
    end

    test "handles API failure response" do
      mock_response = %{
        "success" => false,
        "status_code" => 7,
        "status_message" => "Invalid API key"
      }

      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:error, :token_creation_failed} = TMDBClient.create_request_token()
      end
    end

    test "handles 401 unauthorized response" do
      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 401, body: %{}}}
          end
        ]}
      ] do
        assert {:error, :unauthorized} = TMDBClient.create_request_token()
      end
    end

    test "handles timeout errors" do
      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:error, %Req.TransportError{reason: :timeout}}
          end
        ]}
      ] do
        assert {:error, :timeout} = TMDBClient.create_request_token()
      end
    end

    test "handles invalid response format" do
      mock_response = %{"invalid" => "format"}

      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:error, :invalid_response_format} = TMDBClient.create_request_token()
      end
    end
  end

  describe "create_session/1" do
    test "successfully creates session from approved token" do
      mock_response = %{
        "success" => true,
        "session_id" => "session_abc123"
      }

      with_mocks mock_config() ++ [
        {Req, [], [
          post: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:ok, result} = TMDBClient.create_session("approved_token_123")

        assert %{session_id: "session_abc123"} = result

        # Verify the correct request was made
        assert_called Req.post(:_, :_)
      end
    end

    test "handles session creation failure" do
      mock_response = %{
        "success" => false,
        "status_code" => 17,
        "status_message" => "Session denied"
      }

      with_mocks mock_config() ++ [
        {Req, [], [
          post: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:error, :session_creation_failed} = TMDBClient.create_session("denied_token")
      end
    end

    test "validates token parameter" do
      assert {:error, :invalid_token} = TMDBClient.create_session(nil)
      assert {:error, :invalid_token} = TMDBClient.create_session(123)
      assert {:error, :invalid_token} = TMDBClient.create_session(%{})
    end

    test "handles 401 unauthorized response" do
      with_mocks mock_config() ++ [
        {Req, [], [
          post: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 401, body: %{}}}
          end
        ]}
      ] do
        assert {:error, :unauthorized} = TMDBClient.create_session("token_123")
      end
    end

    test "handles rate limiting" do
      with_mocks mock_config() ++ [
        {Req, [], [
          post: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 429, body: %{}}}
          end
        ]}
      ] do
        assert {:error, :rate_limited} = TMDBClient.create_session("token_123")
      end
    end
  end

  describe "delete_session/1" do
    test "successfully deletes session" do
      mock_response = %{
        "success" => true
      }

      with_mocks mock_config() ++ [
        {Req, [], [
          delete: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:ok, result} = TMDBClient.delete_session("session_123")

        assert %{success: true} = result

        # Verify the correct request was made
        assert_called Req.delete(:_, :_)
      end
    end

    test "handles session deletion failure" do
      mock_response = %{
        "success" => false,
        "status_code" => 3,
        "status_message" => "Authentication failed"
      }

      with_mocks mock_config() ++ [
        {Req, [], [
          delete: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:error, :session_deletion_failed} = TMDBClient.delete_session("invalid_session")
      end
    end

    test "validates session_id parameter" do
      assert {:error, :invalid_session_id} = TMDBClient.delete_session(nil)
      assert {:error, :invalid_session_id} = TMDBClient.delete_session(123)
      assert {:error, :invalid_session_id} = TMDBClient.delete_session(%{})
    end

    test "handles 404 not found response" do
      with_mocks mock_config() ++ [
        {Req, [], [
          delete: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 404, body: %{}}}
          end
        ]}
      ] do
        assert {:error, :not_found} = TMDBClient.delete_session("nonexistent_session")
      end
    end
  end

  describe "get_account_details/1" do
    test "successfully retrieves account details" do
      mock_response = %{
        "id" => 12345,
        "username" => "testuser",
        "name" => "Test User",
        "include_adult" => false,
        "iso_639_1" => "en",
        "iso_3166_1" => "US",
        "avatar" => %{
          "gravatar" => %{"hash" => "gravatar_hash"},
          "tmdb" => %{"avatar_path" => "/path/to/avatar.jpg"}
        }
      }

      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:ok, result} = TMDBClient.get_account_details("session_123")

        assert %{
          "id" => 12345,
          "username" => "testuser",
          "name" => "Test User",
          "include_adult" => false,
          "iso_639_1" => "en",
          "iso_3166_1" => "US",
          "avatar" => %{
            "gravatar" => %{"hash" => "gravatar_hash"},
            "tmdb" => %{"avatar_path" => "/path/to/avatar.jpg"}
          }
        } = result

        # Verify the correct request was made
        assert_called Req.get(:_, :_)
      end
    end

    test "validates session_id parameter" do
      assert {:error, :invalid_session_id} = TMDBClient.get_account_details(nil)
      assert {:error, :invalid_session_id} = TMDBClient.get_account_details(123)
      assert {:error, :invalid_session_id} = TMDBClient.get_account_details(%{})
    end

    test "handles 401 unauthorized response" do
      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 401, body: %{}}}
          end
        ]}
      ] do
        assert {:error, :unauthorized} = TMDBClient.get_account_details("invalid_session")
      end
    end

    test "handles invalid response format" do
      mock_response = %{"invalid" => "format"}

      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 200, body: mock_response}}
          end
        ]}
      ] do
        assert {:error, :invalid_response_format} = TMDBClient.get_account_details("session_123")
      end
    end

    test "handles transport errors" do
      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:error, %Req.TransportError{reason: :econnrefused}}
          end
        ]}
      ] do
        assert {:error, {:transport_error, :econnrefused}} = TMDBClient.get_account_details("session_123")
      end
    end
  end

  describe "error handling" do
    test "handles unexpected status codes" do
      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:ok, %Req.Response{status: 500, body: %{"error" => "Internal server error"}}}
          end
        ]}
      ] do
        assert {:error, {:unexpected_status, 500}} = TMDBClient.create_request_token()
      end
    end

    test "handles generic request errors" do
      with_mocks mock_config() ++ [
        {Req, [], [
          get: fn(_url, _opts) ->
            {:error, :some_generic_error}
          end
        ]}
      ] do
        assert {:error, :some_generic_error} = TMDBClient.create_request_token()
      end
    end
  end

  describe "configuration" do
    test "raises error when API key is not configured" do
      with_mocks [
        {Application, [], [
          get_env: fn :flixir, :tmdb -> [api_key: nil] end
        ]}
      ] do
        assert_raise RuntimeError, ~r/TMDB API key not found/, fn ->
          TMDBClient.create_request_token()
        end
      end
    end

    test "raises error when API key is empty string" do
      with_mocks [
        {Application, [], [
          get_env: fn :flixir, :tmdb -> [api_key: ""] end
        ]}
      ] do
        assert_raise RuntimeError, ~r/Invalid TMDB API key configuration/, fn ->
          TMDBClient.create_request_token()
        end
      end
    end

    test "raises error when API key is invalid type" do
      with_mocks [
        {Application, [], [
          get_env: fn :flixir, :tmdb -> [api_key: 123] end
        ]}
      ] do
        assert_raise RuntimeError, ~r/Invalid TMDB API key configuration/, fn ->
          TMDBClient.create_request_token()
        end
      end
    end
  end
end
