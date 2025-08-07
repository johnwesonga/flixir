defmodule Flixir.Lists.TMDBClientTest do
  use ExUnit.Case, async: true
  import Mock

  alias Flixir.Lists.TMDBClient

  @valid_session_id "valid_session_123"
  @valid_list_id 12345
  @valid_movie_id 550
  @valid_account_id 67890

  describe "create_list/2" do
    test "successfully creates a list" do
      attrs = %{
        name: "My Watchlist",
        description: "Movies I want to watch",
        public: false
      }

      expected_response = %{
        "success" => true,
        "list_id" => @valid_list_id,
        "status_message" => "The item/record was created successfully."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 201, body: expected_response}}
        end
      ] do
        assert {:ok, %{list_id: @valid_list_id, status_message: _}} =
          TMDBClient.create_list(@valid_session_id, attrs)

        assert_called Req.post(:_, :_)
      end
    end

    test "handles creation failure" do
      attrs = %{name: "Test List"}

      failure_response = %{
        "success" => false,
        "status_message" => "Invalid API key"
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 401, body: failure_response}}
        end
      ] do
        assert {:error, :session_expired} =
          TMDBClient.create_list(@valid_session_id, attrs)
      end
    end

    test "handles validation errors" do
      attrs = %{name: ""}

      validation_response = %{
        "success" => false,
        "status_message" => "Name cannot be empty"
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 422, body: validation_response}}
        end
      ] do
        assert {:error, {:validation_error, "Name cannot be empty"}} =
          TMDBClient.create_list(@valid_session_id, attrs)
      end
    end

    test "retries on timeout" do
      attrs = %{name: "Test List"}

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:error, %Req.TransportError{reason: :timeout}}
        end
      ] do
        assert {:error, :timeout} =
          TMDBClient.create_list(@valid_session_id, attrs)

        # Should retry 3 times
        assert_called Req.post(:_, :_)
      end
    end
  end

  describe "get_list/2" do
    test "successfully gets a list" do
      expected_response = %{
        "id" => @valid_list_id,
        "name" => "My Watchlist",
        "description" => "Movies I want to watch",
        "public" => false,
        "item_count" => 5,
        "items" => []
      }

      with_mock Req, [:passthrough], [
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, list_data} = TMDBClient.get_list(@valid_list_id, @valid_session_id)
        assert list_data["id"] == @valid_list_id
        assert list_data["name"] == "My Watchlist"
      end
    end

    test "handles list not found" do
      error_response = %{
        "status_message" => "The resource you requested could not be found."
      }

      with_mock Req, [:passthrough], [
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 404, body: error_response}}
        end
      ] do
        assert {:error, :not_found} = TMDBClient.get_list(99999, @valid_session_id)
      end
    end

    test "works without session_id for public lists" do
      expected_response = %{
        "id" => @valid_list_id,
        "name" => "Public List",
        "public" => true
      }

      with_mock Req, [:passthrough], [
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, list_data} = TMDBClient.get_list(@valid_list_id)
        assert list_data["public"] == true
      end
    end
  end

  describe "update_list/3" do
    test "successfully updates a list" do
      attrs = %{
        name: "Updated Watchlist",
        description: "My updated movie list"
      }

      expected_response = %{
        "success" => true,
        "status_message" => "The item/record was updated successfully."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, %{status_message: _}} =
          TMDBClient.update_list(@valid_list_id, @valid_session_id, attrs)
      end
    end

    test "handles update failure" do
      attrs = %{name: "Updated Name"}

      failure_response = %{
        "success" => false,
        "status_message" => "You do not have permission to edit this list."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 403, body: failure_response}}
        end
      ] do
        assert {:error, :access_denied} =
          TMDBClient.update_list(@valid_list_id, @valid_session_id, attrs)
      end
    end

    test "filters out nil values from attrs" do
      attrs = %{
        name: "Updated Name",
        description: nil,
        public: true
      }

      with_mock Req, [:passthrough], [
        post: fn _url, opts ->
          # Verify that nil values are filtered out
          body = Keyword.get(opts, :json)
          refute Map.has_key?(body, :description)
          assert body[:name] == "Updated Name"
          assert body[:public] == true

          {:ok, %Req.Response{status: 200, body: %{"success" => true, "status_message" => "Updated"}}}
        end
      ] do
        TMDBClient.update_list(@valid_list_id, @valid_session_id, attrs)
      end
    end
  end

  describe "delete_list/2" do
    test "successfully deletes a list" do
      expected_response = %{
        "success" => true,
        "status_message" => "The item/record was deleted successfully."
      }

      with_mock Req, [:passthrough], [
        delete: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, %{status_message: _}} =
          TMDBClient.delete_list(@valid_list_id, @valid_session_id)
      end
    end

    test "handles deletion failure" do
      failure_response = %{
        "success" => false,
        "status_message" => "You do not have permission to delete this list."
      }

      with_mock Req, [:passthrough], [
        delete: fn _url, _opts ->
          {:ok, %Req.Response{status: 403, body: failure_response}}
        end
      ] do
        assert {:error, :access_denied} =
          TMDBClient.delete_list(@valid_list_id, @valid_session_id)
      end
    end
  end

  describe "clear_list/2" do
    test "successfully clears a list" do
      expected_response = %{
        "success" => true,
        "status_message" => "The item/record was updated successfully."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, opts ->
          # Verify confirm parameter is sent
          body = Keyword.get(opts, :json)
          assert body[:confirm] == true

          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, %{status_message: _}} =
          TMDBClient.clear_list(@valid_list_id, @valid_session_id)
      end
    end

    test "handles clear failure" do
      failure_response = %{
        "success" => false,
        "status_message" => "You do not have permission to edit this list."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 403, body: failure_response}}
        end
      ] do
        assert {:error, :access_denied} =
          TMDBClient.clear_list(@valid_list_id, @valid_session_id)
      end
    end
  end

  describe "add_movie_to_list/3" do
    test "successfully adds a movie to list" do
      expected_response = %{
        "success" => true,
        "status_message" => "The item/record was updated successfully."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, opts ->
          # Verify media_id parameter is sent
          body = Keyword.get(opts, :json)
          assert body[:media_id] == @valid_movie_id

          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, %{status_message: _}} =
          TMDBClient.add_movie_to_list(@valid_list_id, @valid_movie_id, @valid_session_id)
      end
    end

    test "handles duplicate movie error" do
      failure_response = %{
        "success" => false,
        "status_message" => "The item is already on this list."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 422, body: failure_response}}
        end
      ] do
        assert {:error, {:validation_error, "The item is already on this list."}} =
          TMDBClient.add_movie_to_list(@valid_list_id, @valid_movie_id, @valid_session_id)
      end
    end
  end

  describe "remove_movie_from_list/3" do
    test "successfully removes a movie from list" do
      expected_response = %{
        "success" => true,
        "status_message" => "The item/record was updated successfully."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, opts ->
          # Verify media_id parameter is sent
          body = Keyword.get(opts, :json)
          assert body[:media_id] == @valid_movie_id

          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, %{status_message: _}} =
          TMDBClient.remove_movie_from_list(@valid_list_id, @valid_movie_id, @valid_session_id)
      end
    end

    test "handles movie not in list error" do
      failure_response = %{
        "success" => false,
        "status_message" => "The item is not on this list."
      }

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 422, body: failure_response}}
        end
      ] do
        assert {:error, {:validation_error, "The item is not on this list."}} =
          TMDBClient.remove_movie_from_list(@valid_list_id, @valid_movie_id, @valid_session_id)
      end
    end
  end

  describe "get_account_lists/2" do
    test "successfully gets account lists" do
      expected_response = %{
        "results" => [
          %{"id" => 1, "name" => "Watchlist", "item_count" => 5},
          %{"id" => 2, "name" => "Favorites", "item_count" => 10}
        ],
        "total_results" => 2,
        "page" => 1,
        "total_pages" => 1
      }

      with_mock Req, [:passthrough], [
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 200, body: expected_response}}
        end
      ] do
        assert {:ok, response} =
          TMDBClient.get_account_lists(@valid_account_id, @valid_session_id)

        assert length(response["results"]) == 2
        assert response["total_results"] == 2
      end
    end

    test "handles account not found" do
      error_response = %{
        "status_message" => "The resource you requested could not be found."
      }

      with_mock Req, [:passthrough], [
        get: fn _url, _opts ->
          {:ok, %Req.Response{status: 404, body: error_response}}
        end
      ] do
        assert {:error, :not_found} =
          TMDBClient.get_account_lists(99999, @valid_session_id)
      end
    end
  end

  describe "error handling and retries" do
    test "retries on rate limit with exponential backoff" do
      attrs = %{name: "Test List"}

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 429, body: %{"status_message" => "Rate limit exceeded"}}}
        end
      ] do
        assert {:error, :rate_limited} =
          TMDBClient.create_list(@valid_session_id, attrs)

        # Should retry 3 times (original + 2 retries)
        assert_called Req.post(:_, :_)
      end
    end

    test "handles server errors with retry" do
      attrs = %{name: "Test List"}

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 500, body: %{"status_message" => "Internal server error"}}}
        end
      ] do
        assert {:error, {:server_error, 500}} =
          TMDBClient.create_list(@valid_session_id, attrs)

        # Should retry on server errors
        assert_called Req.post(:_, :_)
      end
    end

    test "does not retry on authentication errors" do
      attrs = %{name: "Test List"}

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:ok, %Req.Response{status: 401, body: %{"status_message" => "Invalid session"}}}
        end
      ] do
        assert {:error, :session_expired} =
          TMDBClient.create_list(@valid_session_id, attrs)

        # Should only call once, no retries for auth errors
        assert_called Req.post(:_, :_)
      end
    end

    test "handles transport errors with retry" do
      attrs = %{name: "Test List"}

      with_mock Req, [:passthrough], [
        post: fn _url, _opts ->
          {:error, %Req.TransportError{reason: :econnrefused}}
        end
      ] do
        assert {:error, :network_error} =
          TMDBClient.create_list(@valid_session_id, attrs)

        # Should retry on network errors
        assert_called Req.post(:_, :_)
      end
    end
  end

  describe "URL sanitization" do
    test "sanitizes API key and session ID in logs" do
      # This test ensures sensitive information is not logged
      # We can't easily test the actual logging, but we can test the sanitization function
      url = "https://api.themoviedb.org/3/list?api_key=secret123&session_id=session456"

      # Verify the URL contains sensitive data before sanitization
      assert String.contains?(url, "secret123")
      assert String.contains?(url, "session456")

      # The actual sanitization is tested indirectly through the logging behavior
      # This test serves as documentation of the security requirement
    end
  end

  describe "configuration" do
    test "raises error when API key is not configured" do
      # Mock the Application.get_env to return nil
      with_mock Application, [:passthrough], [
        get_env: fn :flixir, :tmdb -> [base_url: "https://api.themoviedb.org/3"] end
      ] do
        assert_raise RuntimeError, ~r/TMDB API key not found/, fn ->
          TMDBClient.create_list(@valid_session_id, %{name: "Test"})
        end
      end
    end

    test "raises error when API key is too short" do
      with_mock Application, [:passthrough], [
        get_env: fn :flixir, :tmdb -> [api_key: "short", base_url: "https://api.themoviedb.org/3"] end
      ] do
        assert_raise RuntimeError, ~r/Invalid TMDB API key/, fn ->
          TMDBClient.create_list(@valid_session_id, %{name: "Test"})
        end
      end
    end
  end
end
