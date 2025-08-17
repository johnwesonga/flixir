defmodule Flixir.Lists.TMDBClient do
  @moduledoc """
  HTTP client for TMDB Lists API operations.

  Handles all list management operations through TMDB's native API,
  including creating, reading, updating, and deleting lists, as well as
  adding and removing movies from lists.

  This module includes comprehensive error handling with retry logic,
  exponential backoff, and graceful degradation for TMDB API issues.

  ## Architecture

  The client uses a unified base URL for all TMDB API operations, providing
  a simple and consistent approach to URL building across all endpoints.
  """

  require Logger

  @default_timeout 10_000
  @max_retries 3

  # List Management Functions

  @doc """
  Creates a new list on TMDB.

  ## Parameters
  - `session_id`: The authenticated TMDB session ID
  - `attrs`: Map containing list attributes (name, description, public)

  ## Returns
  - `{:ok, %{list_id: integer(), status_message: string()}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.create_list("session_123", %{
      ...>   name: "My Watchlist",
      ...>   description: "Movies I want to watch",
      ...>   public: false
      ...> })
      {:ok, %{list_id: 12345, status_message: "The item/record was created successfully."}}
  """
  def create_list(session_id, attrs) when is_binary(session_id) and is_map(attrs) do
    context = %{
      operation: :create_list,
      attempt: 1,
      session_id: session_id,
      additional_info: %{list_name: Map.get(attrs, :name) || Map.get(attrs, "name")}
    }

    body = %{
      name: attrs[:name] || attrs["name"],
      description: attrs[:description] || attrs["description"] || "",
      public: attrs[:public] || attrs["public"] || false
    }

    params = %{session_id: session_id}
    make_request_with_retry(:post, "/list", body, context, &parse_create_list_response/1, params)
  end

  @doc """
  Gets list details from TMDB.

  ## Parameters
  - `list_id`: The TMDB list ID
  - `session_id`: The authenticated TMDB session ID (optional for public lists)

  ## Returns
  - `{:ok, list_data}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.get_list(12345, "session_123")
      {:ok, %{
        "id" => 12345,
        "name" => "My Watchlist",
        "description" => "Movies I want to watch",
        "public" => false,
        "item_count" => 5,
        "items" => [...]
      }}
  """
  def get_list(list_id, session_id \\ nil) when is_integer(list_id) do
    context = %{
      operation: :get_list,
      attempt: 1,
      session_id: session_id,
      additional_info: %{list_id: list_id}
    }

    params = if session_id, do: %{session_id: session_id}, else: %{}
    make_request_with_retry(:get, "/list/#{list_id}", nil, context, &parse_list_response/1, params)
  end

  @doc """
  Updates an existing list on TMDB.

  ## Parameters
  - `list_id`: The TMDB list ID
  - `session_id`: The authenticated TMDB session ID
  - `attrs`: Map containing updated attributes

  ## Returns
  - `{:ok, %{status_message: string()}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.update_list(12345, "session_123", %{
      ...>   name: "Updated Watchlist",
      ...>   description: "My updated movie list"
      ...> })
      {:ok, %{status_message: "The item/record was updated successfully."}}
  """
  def update_list(list_id, session_id, attrs)
      when is_integer(list_id) and is_binary(session_id) and is_map(attrs) do
    context = %{
      operation: :update_list,
      attempt: 1,
      session_id: session_id,
      additional_info: %{list_id: list_id}
    }

    body = %{
      name: attrs[:name] || attrs["name"],
      description: attrs[:description] || attrs["description"],
      public: attrs[:public] || attrs["public"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    params = %{session_id: session_id}
    make_request_with_retry(:post, "/list/#{list_id}", body, context, &parse_update_response/1, params)
  end

  @doc """
  Deletes a list from TMDB.

  ## Parameters
  - `list_id`: The TMDB list ID
  - `session_id`: The authenticated TMDB session ID

  ## Returns
  - `{:ok, %{status_message: string()}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.delete_list(12345, "session_123")
      {:ok, %{status_message: "The item/record was deleted successfully."}}
  """
  def delete_list(list_id, session_id) when is_integer(list_id) and is_binary(session_id) do
    context = %{
      operation: :delete_list,
      attempt: 1,
      session_id: session_id,
      additional_info: %{list_id: list_id}
    }

    params = %{session_id: session_id}
    make_request_with_retry(:delete, "/list/#{list_id}", nil, context, &parse_delete_response/1, params)
  end

  @doc """
  Clears all items from a TMDB list.

  ## Parameters
  - `list_id`: The TMDB list ID
  - `session_id`: The authenticated TMDB session ID

  ## Returns
  - `{:ok, %{status_message: string()}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.clear_list(12345, "session_123")
      {:ok, %{status_message: "The item/record was updated successfully."}}
  """
  def clear_list(list_id, session_id) when is_integer(list_id) and is_binary(session_id) do
    context = %{
      operation: :clear_list,
      attempt: 1,
      session_id: session_id,
      additional_info: %{list_id: list_id}
    }

    body = %{confirm: true}
    params = %{session_id: session_id}
    make_request_with_retry(:post, "/list/#{list_id}/clear", body, context, &parse_clear_response/1, params)
  end

  # Movie Management Functions

  @doc """
  Adds a movie to a TMDB list.

  ## Parameters
  - `list_id`: The TMDB list ID
  - `movie_id`: The TMDB movie ID
  - `session_id`: The authenticated TMDB session ID

  ## Returns
  - `{:ok, %{status_message: string()}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.add_movie_to_list(12345, 550, "session_123")
      {:ok, %{status_message: "The item/record was updated successfully."}}
  """
  def add_movie_to_list(list_id, movie_id, session_id)
      when is_integer(list_id) and is_integer(movie_id) and is_binary(session_id) do
    context = %{
      operation: :add_movie_to_list,
      attempt: 1,
      session_id: session_id,
      additional_info: %{list_id: list_id, movie_id: movie_id}
    }

    body = %{media_id: movie_id}
    params = %{session_id: session_id}
    make_request_with_retry(:post, "/list/#{list_id}/add_item", body, context, &parse_movie_operation_response/1, params)
  end

  @doc """
  Removes a movie from a TMDB list.

  ## Parameters
  - `list_id`: The TMDB list ID
  - `movie_id`: The TMDB movie ID
  - `session_id`: The authenticated TMDB session ID

  ## Returns
  - `{:ok, %{status_message: string()}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.remove_movie_from_list(12345, 550, "session_123")
      {:ok, %{status_message: "The item/record was updated successfully."}}
  """
  def remove_movie_from_list(list_id, movie_id, session_id)
      when is_integer(list_id) and is_integer(movie_id) and is_binary(session_id) do
    context = %{
      operation: :remove_movie_from_list,
      attempt: 1,
      session_id: session_id,
      additional_info: %{list_id: list_id, movie_id: movie_id}
    }

    body = %{media_id: movie_id}
    params = %{session_id: session_id}
    make_request_with_retry(:post, "/list/#{list_id}/remove_item", body, context, &parse_movie_operation_response/1, params)
  end

  @doc """
  Gets all lists for a TMDB account.

  ## Parameters
  - `account_id`: The TMDB account ID
  - `session_id`: The authenticated TMDB session ID

  ## Returns
  - `{:ok, %{results: [list_data], ...}}` on success
  - `{:error, classified_error}` on failure

  ## Examples

      iex> Flixir.Lists.TMDBClient.get_account_lists(12345, "session_123")
      {:ok, %{
        "results" => [
          %{"id" => 1, "name" => "Watchlist", "item_count" => 5},
          %{"id" => 2, "name" => "Favorites", "item_count" => 10}
        ],
        "total_results" => 2
      }}
  """
  def get_account_lists(account_id, session_id)
      when is_integer(account_id) and is_binary(session_id) do
    context = %{
      operation: :get_account_lists,
      attempt: 1,
      session_id: session_id,
      additional_info: %{account_id: account_id}
    }

    params = %{session_id: session_id}
    make_request_with_retry(:get, "/account/#{account_id}/lists", nil, context, &parse_account_lists_response/1, params)
  end

  # Private functions

  defp make_request_with_retry(method, path, body, context, parser, params \\ %{}) do
    url = build_url(path, params)

    case make_single_request(method, url, body, context) do
      {:ok, response_body} ->
        parser.(response_body)

      {:error, reason} ->
        error_result = classify_error(reason, context)

        if should_retry?(error_result, context.attempt) do
          delay = retry_delay(context.attempt, elem(error_result, 1))

          Logger.info("Retrying #{context.operation} after #{delay}ms", %{
            attempt: context.attempt,
            operation: context.operation,
            delay_ms: delay
          })

          # Skip sleep in test environment to avoid delays
          unless Mix.env() == :test do
            :timer.sleep(delay)
          end

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

    Logger.debug("Making TMDB Lists API request", %{
      method: method,
      url: sanitize_url_for_logging(url),
      operation: context.operation,
      attempt: context.attempt,
      body: if(body, do: inspect(body), else: "nil")
    })

    case apply(Req, method, [url, options]) do
      {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
        Logger.debug("TMDB Lists API request successful", %{
          operation: context.operation,
          attempt: context.attempt,
          status: status
        })
        {:ok, body}

      {:ok, %Req.Response{status: 401, body: body}} ->
        Logger.warning("TMDB Lists API authentication failed", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 401,
          response_body: inspect(body)
        })
        {:error, :unauthorized}

      {:ok, %Req.Response{status: 403, body: body}} ->
        Logger.warning("TMDB Lists API access forbidden", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 403,
          response_body: inspect(body)
        })
        {:error, :forbidden}

      {:ok, %Req.Response{status: 404, body: body}} ->
        Logger.warning("TMDB resource not found", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 404,
          url: sanitize_url_for_logging(url),
          response_body: inspect(body),
          session_id_present: Map.has_key?(context, :session_id)
        })
        {:error, :not_found}

      {:ok, %Req.Response{status: 422, body: body}} ->
        Logger.warning("TMDB Lists API validation error", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 422,
          response_body: inspect(body)
        })
        {:error, {:validation_error, body}}

      {:ok, %Req.Response{status: 429, body: body}} ->
        Logger.warning("TMDB Lists API rate limit exceeded", %{
          operation: context.operation,
          attempt: context.attempt,
          status: 429,
          response_body: inspect(body)
        })
        {:error, :rate_limited}

      {:ok, %Req.Response{status: status, body: body}} when status >= 500 ->
        Logger.error("TMDB Lists API server error", %{
          operation: context.operation,
          attempt: context.attempt,
          status: status,
          response_body: inspect(body)
        })
        {:error, {:server_error, status}}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("TMDB Lists API unexpected status", %{
          operation: context.operation,
          attempt: context.attempt,
          status: status,
          response_body: inspect(body)
        })
        {:error, {:unexpected_status, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        Logger.warning("TMDB Lists API request timed out", %{
          operation: context.operation,
          attempt: context.attempt,
          timeout_ms: get_timeout()
        })
        {:error, :timeout}

      {:error, %Req.TransportError{reason: reason}} ->
        Logger.error("TMDB Lists API transport error", %{
          operation: context.operation,
          attempt: context.attempt,
          transport_error: inspect(reason)
        })
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        Logger.error("TMDB Lists API request failed", %{
          operation: context.operation,
          attempt: context.attempt,
          error: inspect(reason)
        })
        {:error, reason}
    end
  end

  # Response parsers

  defp parse_create_list_response(%{"success" => true, "list_id" => list_id, "status_message" => message})
      when is_integer(list_id) do
    Logger.debug("Successfully parsed create list response", %{list_id: list_id})
    {:ok, %{list_id: list_id, status_message: message}}
  end

  defp parse_create_list_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB list creation failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :list_creation_failed}
  end

  defp parse_create_list_response(response) do
    Logger.error("Invalid create list response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_list_response(%{"id" => id, "name" => name} = list_data)
      when is_integer(id) and is_binary(name) do
    Logger.debug("Successfully parsed list response", %{list_id: id, name: name})
    {:ok, list_data}
  end

  defp parse_list_response(%{"status_message" => message} = response) do
    Logger.error("TMDB get list request failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :list_not_found}
  end

  defp parse_list_response(response) do
    Logger.error("Invalid list response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_update_response(%{"success" => true, "status_message" => message}) do
    Logger.debug("Successfully parsed update response")
    {:ok, %{status_message: message}}
  end

  defp parse_update_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB list update failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :list_update_failed}
  end

  defp parse_update_response(response) do
    Logger.error("Invalid update response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_delete_response(%{"success" => true, "status_message" => message}) do
    Logger.debug("Successfully parsed delete response")
    {:ok, %{status_message: message}}
  end

  defp parse_delete_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB list deletion failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :list_deletion_failed}
  end

  defp parse_delete_response(response) do
    Logger.error("Invalid delete response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_clear_response(%{"success" => true, "status_message" => message}) do
    Logger.debug("Successfully parsed clear response")
    {:ok, %{status_message: message}}
  end

  defp parse_clear_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB list clear failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :list_clear_failed}
  end

  defp parse_clear_response(response) do
    Logger.error("Invalid clear response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_movie_operation_response(%{"success" => true, "status_message" => message}) do
    Logger.debug("Successfully parsed movie operation response")
    {:ok, %{status_message: message}}
  end

  defp parse_movie_operation_response(%{"success" => false, "status_message" => message} = response) do
    Logger.error("TMDB movie operation failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :movie_operation_failed}
  end

  defp parse_movie_operation_response(response) do
    Logger.error("Invalid movie operation response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  defp parse_account_lists_response(%{"results" => results} = response) when is_list(results) do
    Logger.debug("Successfully parsed account lists response", %{
      list_count: length(results)
    })
    {:ok, response}
  end

  defp parse_account_lists_response(%{"status_message" => message} = response) do
    Logger.error("TMDB account lists request failed", %{
      status_message: message,
      response: inspect(response)
    })
    {:error, :account_lists_failed}
  end

  defp parse_account_lists_response(response) do
    Logger.error("Invalid account lists response format", %{
      response: inspect(response)
    })
    {:error, :invalid_response_format}
  end

  # Error handling and retry logic

  defp classify_error(reason, context) do
    case reason do
      :unauthorized ->
        {:error, :session_expired}

      :forbidden ->
        {:error, :access_denied}

      :not_found ->
        {:error, :not_found}

      {:validation_error, body} ->
        {:error, {:validation_error, extract_validation_message(body)}}

      :rate_limited ->
        {:error, :rate_limited}

      {:server_error, status} ->
        {:error, {:server_error, status}}

      :timeout ->
        {:error, :timeout}

      {:transport_error, _reason} ->
        {:error, :network_error}

      _ ->
        Logger.error("Unclassified TMDB Lists API error", %{
          operation: context.operation,
          error: inspect(reason)
        })
        {:error, :api_error}
    end
  end

  defp should_retry?({:error, error_type}, attempt) when attempt < @max_retries do
    case error_type do
      :timeout -> true
      :network_error -> true
      :rate_limited -> true
      {:server_error, _} -> true
      _ -> false
    end
  end

  defp should_retry?(_, _), do: false

  defp retry_delay(attempt, error_type) do
    base_delay = case error_type do
      :rate_limited -> 5000  # 5 seconds for rate limits
      _ -> 1000              # 1 second base for other retryable errors
    end

    # Exponential backoff with jitter
    delay = base_delay * :math.pow(2, attempt - 1)
    jitter = :rand.uniform(1000)
    round(delay + jitter)
  end

  defp extract_validation_message(%{"status_message" => message}), do: message
  defp extract_validation_message(_), do: "Validation failed"

  # Utility functions

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
    # Remove API key and session ID from URL for logging
    url
    |> String.replace(~r/api_key=[^&]+/, "api_key=***")
    |> String.replace(~r/session_id=[^&]+/, "session_id=***")
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
end
