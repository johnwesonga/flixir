defmodule Flixir.Auth do
  @moduledoc """
  Authentication context for TMDB user sessions.
  """

  import Ecto.Query, warn: false
  alias Flixir.Repo
  alias Flixir.Auth.Session
  alias Flixir.Auth.TMDBClient
  alias Flixir.Auth.ErrorHandler

  require Logger

  # Authentication Flow Functions

  @doc """
  Initiates TMDB authentication flow by creating a request token.

  This is the first step in the TMDB authentication process. The returned
  token must be approved by the user on the TMDB website.

  ## Returns
  - `{:ok, auth_url}` - URL to redirect user to for authentication
  - `{:error, reason}` - Error occurred during token creation

  ## Examples

      iex> start_authentication()
      {:ok, "https://www.themoviedb.org/authenticate/abc123?redirect_to=..."}

      iex> start_authentication()
      {:error, :token_creation_failed}
  """
  def start_authentication do
    Logger.info("Starting TMDB authentication flow")

    case TMDBClient.create_request_token() do
      {:ok, %{request_token: token}} ->
        auth_url = build_auth_url(token)
        Logger.info("Successfully created request token, redirecting to TMDB")
        {:ok, auth_url}

      {:error, reason} ->
        Logger.error("Failed to start authentication", %{
          error: inspect(reason),
          user_message: ErrorHandler.format_user_error({:error, reason})
        })
        {:error, reason}
    end
  end

  @doc """
  Completes authentication with an approved request token.

  This function handles the final step of TMDB authentication by creating
  a session from the approved token and storing it in the database.

  ## Parameters
  - `request_token` - The approved request token from TMDB callback

  ## Returns
  - `{:ok, session}` - Successfully created and stored session
  - `{:error, reason}` - Error occurred during session creation or storage

  ## Examples

      iex> complete_authentication("approved_token_123")
      {:ok, %Session{tmdb_session_id: "session_abc", username: "user123"}}

      iex> complete_authentication("invalid_token")
      {:error, :session_creation_failed}
  """
  def complete_authentication(request_token) when is_binary(request_token) do
    Logger.info("Completing TMDB authentication", %{
      token_length: String.length(request_token)
    })

    with {:ok, %{session_id: session_id}} <- TMDBClient.create_session(request_token),
         {:ok, account_details} <- TMDBClient.get_account_details(session_id),
         {:ok, session} <- create_session_from_account(session_id, account_details) do
      Logger.info("Successfully completed authentication", %{
        user_id: account_details["id"],
        username: account_details["username"],
        session_id: session_id
      })

      {:ok, session}
    else
      {:error, reason} ->
        Logger.error("Failed to complete authentication", %{
          error: inspect(reason),
          token_length: String.length(request_token),
          user_message: ErrorHandler.format_user_error({:error, reason})
        })

        {:error, reason}
    end
  end

  def complete_authentication(_invalid_token) do
    Logger.warning("Attempted to complete authentication with invalid token format")
    {:error, :invalid_token}
  end

  @doc """
  Validates an existing session and updates last accessed time.

  Checks if the session exists, is not expired, and updates the last
  accessed timestamp if valid.

  ## Parameters
  - `session_id` - The TMDB session ID to validate

  ## Returns
  - `{:ok, session}` - Valid session with updated last accessed time
  - `{:error, reason}` - Session invalid, expired, or not found

  ## Examples

      iex> validate_session("valid_session_123")
      {:ok, %Session{last_accessed_at: ~U[2024-01-01 12:00:00Z]}}

      iex> validate_session("expired_session")
      {:error, :session_expired}

      iex> validate_session("nonexistent")
      {:error, :not_found}
  """
  def validate_session(session_id) when is_binary(session_id) do
    Logger.debug("Validating session", %{session_id: session_id})

    case get_session(session_id) do
      {:ok, session} ->
        if session_active?(session) do
          case update_last_accessed(session) do
            {:ok, updated_session} ->
              Logger.debug("Session validated and updated", %{
                session_id: session_id,
                username: session.username
              })
              {:ok, updated_session}
            {:error, reason} ->
              Logger.error("Failed to update session last accessed time", %{
                session_id: session_id,
                error: inspect(reason)
              })
              {:error, reason}
          end
        else
          Logger.info("Session expired, cleaning up", %{
            session_id: session_id,
            username: session.username,
            expires_at: session.expires_at,
            last_accessed_at: session.last_accessed_at
          })
          delete_session(session)
          {:error, :session_expired}
        end

      {:error, :not_found} ->
        Logger.debug("Session not found", %{session_id: session_id})
        {:error, :not_found}
    end
  end

  def validate_session(_invalid_session_id) do
    Logger.warning("Attempted to validate session with invalid session ID format")
    {:error, :invalid_session_id}
  end

  @doc """
  Logs out a user by invalidating their session.

  This function removes the session from both TMDB and the local database,
  ensuring complete logout.

  ## Parameters
  - `session_id` - The TMDB session ID to logout

  ## Returns
  - `:ok` - Successfully logged out
  - `{:error, reason}` - Error occurred during logout

  ## Examples

      iex> logout("session_123")
      :ok

      iex> logout("nonexistent_session")
      {:error, :not_found}
  """
  def logout(session_id) when is_binary(session_id) do
    Logger.info("Starting logout process", %{session_id: session_id})

    case get_session(session_id) do
      {:ok, session} ->
        # Try to delete from TMDB first, but don't fail if it's already gone
        case TMDBClient.delete_session(session_id) do
          {:ok, _} ->
            Logger.info("Successfully deleted TMDB session", %{
              session_id: session_id,
              username: session.username
            })

          {:error, reason} ->
            # Log but don't fail - session might already be expired on TMDB side
            Logger.warning("Failed to delete TMDB session (continuing with local cleanup)", %{
              session_id: session_id,
              username: session.username,
              error: inspect(reason),
              user_message: ErrorHandler.format_user_error({:error, reason})
            })
        end

        # Always delete from local database
        case delete_session(session) do
          {:ok, _} ->
            Logger.info("Successfully logged out user", %{
              session_id: session_id,
              username: session.username
            })
            :ok

          {:error, reason} ->
            Logger.error("Failed to delete local session", %{
              session_id: session_id,
              username: session.username,
              error: inspect(reason)
            })
            {:error, reason}
        end

      {:error, :not_found} ->
        Logger.warning("Attempted to logout non-existent session", %{
          session_id: session_id
        })
        {:error, :not_found}
    end
  end

  def logout(_invalid_session_id) do
    Logger.warning("Attempted to logout with invalid session ID format")
    {:error, :invalid_session_id}
  end

  @doc """
  Gets current user information from a session.

  Retrieves fresh user data from TMDB API using the session ID.

  ## Parameters
  - `session_id` - The TMDB session ID

  ## Returns
  - `{:ok, user_data}` - Current user information from TMDB
  - `{:error, reason}` - Session invalid or API error

  ## Examples

      iex> get_current_user("session_123")
      {:ok, %{
        "id" => 12345,
        "username" => "user123",
        "name" => "John Doe",
        "avatar" => %{...}
      }}

      iex> get_current_user("invalid_session")
      {:error, :unauthorized}
  """
  def get_current_user(session_id) when is_binary(session_id) do
    Logger.debug("Getting current user", %{session_id: session_id})

    case validate_session(session_id) do
      {:ok, session} ->
        case TMDBClient.get_account_details(session_id) do
          {:ok, user_data} ->
            Logger.debug("Successfully retrieved user data", %{
              session_id: session_id,
              user_id: user_data["id"],
              username: user_data["username"]
            })
            {:ok, user_data}
          {:error, reason} ->
            Logger.error("Failed to get current user data", %{
              session_id: session_id,
              username: session.username,
              error: inspect(reason),
              user_message: ErrorHandler.format_user_error({:error, reason})
            })
            {:error, reason}
        end

      {:error, reason} ->
        Logger.debug("Session validation failed for get_current_user", %{
          session_id: session_id,
          error: inspect(reason)
        })
        {:error, reason}
    end
  end

  def get_current_user(_invalid_session_id) do
    Logger.warning("Attempted to get current user with invalid session ID format")
    {:error, :invalid_session_id}
  end

  # Session Management Functions

  @doc """
  Gets a session by TMDB session ID.

  ## Examples

      iex> get_session("valid_session_id")
      {:ok, %Session{}}

      iex> get_session("invalid_session_id")
      {:error, :not_found}

  """
  def get_session(tmdb_session_id) when is_binary(tmdb_session_id) do
    case Repo.get_by(Session, tmdb_session_id: tmdb_session_id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @doc """
  Creates a new session.

  ## Examples

      iex> create_session(%{tmdb_session_id: "session123", tmdb_user_id: 1, username: "user"})
      {:ok, %Session{}}

      iex> create_session(%{invalid: "data"})
      {:error, %Ecto.Changeset{}}

  """
  def create_session(attrs \\ %{}) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a session's last accessed time.

  ## Examples

      iex> update_last_accessed(session)
      {:ok, %Session{}}

  """
  def update_last_accessed(%Session{} = session) do
    session
    |> Session.update_last_accessed_changeset()
    |> Repo.update()
  end

  @doc """
  Deletes a session.

  ## Examples

      iex> delete_session(session)
      {:ok, %Session{}}

      iex> delete_session(session)
      {:error, %Ecto.Changeset{}}

  """
  def delete_session(%Session{} = session) do
    Repo.delete(session)
  end

  @doc """
  Deletes a session by TMDB session ID.

  ## Examples

      iex> delete_session_by_id("session123")
      {:ok, %Session{}}

      iex> delete_session_by_id("nonexistent")
      {:error, :not_found}

  """
  def delete_session_by_id(tmdb_session_id) when is_binary(tmdb_session_id) do
    case get_session(tmdb_session_id) do
      {:ok, session} -> delete_session(session)
      error -> error
    end
  end

  @doc """
  Validates if a session is still active (not expired and not idle).

  ## Examples

      iex> session_active?(session)
      true

      iex> session_active?(expired_session)
      false

  """
  def session_active?(%Session{expires_at: expires_at, last_accessed_at: last_accessed_at}) do
    now = DateTime.utc_now()

    # Check if session has expired
    session_not_expired = DateTime.compare(now, expires_at) == :lt

    # Check if session is not idle (last accessed within idle timeout)
    max_idle_seconds = get_session_max_idle()
    idle_cutoff = DateTime.add(now, -max_idle_seconds, :second)
    session_not_idle = DateTime.compare(last_accessed_at, idle_cutoff) == :gt

    session_not_expired and session_not_idle
  end

  @doc """
  Cleans up expired and idle sessions from the database.

  ## Examples

      iex> cleanup_expired_sessions()
      {3, nil}  # 3 sessions deleted

  """
  def cleanup_expired_sessions do
    now = DateTime.utc_now()
    max_idle_seconds = get_session_max_idle()
    idle_cutoff = DateTime.add(now, -max_idle_seconds, :second)

    from(s in Session,
      where: s.expires_at < ^now or s.last_accessed_at < ^idle_cutoff
    )
    |> Repo.delete_all()
  end

  @doc """
  Gets all sessions for a specific TMDB user ID.

  ## Examples

      iex> get_user_sessions(123)
      [%Session{}, %Session{}]

  """
  def get_user_sessions(tmdb_user_id) when is_integer(tmdb_user_id) do
    from(s in Session, where: s.tmdb_user_id == ^tmdb_user_id)
    |> Repo.all()
  end

  @doc """
  Gets the current valid session for a user.

  Returns the most recent valid session for the given user ID.

  ## Parameters
  - tmdb_user_id: The TMDB user ID

  ## Returns
  - `{:ok, session_id}` - Valid session found
  - `{:error, :no_valid_session}` - No valid session found
  """
  def get_user_session(tmdb_user_id) when is_integer(tmdb_user_id) do
    now = DateTime.utc_now()

    case from(s in Session,
      where: s.tmdb_user_id == ^tmdb_user_id and
             s.expires_at > ^now and
             s.last_accessed_at > ^DateTime.add(now, -get_session_max_idle(), :second),
      order_by: [desc: s.last_accessed_at],
      limit: 1
    )
    |> Repo.one() do
      nil -> {:error, :no_valid_session}
      session -> {:ok, session.tmdb_session_id}
    end
  end

  # Private helper functions

  defp build_auth_url(request_token) do
    redirect_url = get_redirect_url()

    "https://www.themoviedb.org/authenticate/#{request_token}?redirect_to=#{URI.encode(redirect_url)}"
  end

  defp create_session_from_account(session_id, account_details) do
    # Calculate session expiration (TMDB sessions typically last 24 hours)
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(get_session_timeout(), :second)
      |> DateTime.truncate(:second)

    session_attrs = %{
      tmdb_session_id: session_id,
      tmdb_user_id: account_details["id"],
      username: account_details["username"],
      expires_at: expires_at
    }

    create_session(session_attrs)
  end

  defp get_redirect_url do
    Application.get_env(:flixir, :tmdb_auth)[:redirect_url] ||
      "http://localhost:4000/auth/callback"
  end

  defp get_session_timeout do
    # 24 hours default
    Application.get_env(:flixir, :tmdb_auth)[:session_timeout] || 86400
  end

  defp get_session_max_idle do
    # 2 hours default idle timeout
    Application.get_env(:flixir, :tmdb_auth)[:session_max_idle] || 7200
  end
end
