defmodule Flixir.Auth do
  @moduledoc """
  Authentication context for TMDB user sessions.
  """

  import Ecto.Query, warn: false
  alias Flixir.Repo
  alias Flixir.Auth.Session

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
  Validates if a session is still active (not expired).

  ## Examples

      iex> session_active?(session)
      true

      iex> session_active?(expired_session)
      false

  """
  def session_active?(%Session{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end

  @doc """
  Cleans up expired sessions from the database.

  ## Examples

      iex> cleanup_expired_sessions()
      {3, nil}  # 3 sessions deleted

  """
  def cleanup_expired_sessions do
    now = DateTime.utc_now()

    from(s in Session, where: s.expires_at < ^now)
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
end
