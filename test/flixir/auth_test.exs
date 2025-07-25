defmodule Flixir.AuthTest do
  use Flixir.DataCase

  alias Flixir.Auth
  alias Flixir.Auth.Session

  describe "sessions" do
    @valid_attrs %{
      tmdb_session_id: "session123",
      tmdb_user_id: 42,
      username: "testuser",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)
    }

    @invalid_attrs %{
      tmdb_session_id: nil,
      tmdb_user_id: nil,
      username: nil,
      expires_at: nil
    }

    test "get_session/1 returns the session with given tmdb_session_id" do
      {:ok, session} = Auth.create_session(@valid_attrs)
      assert {:ok, found_session} = Auth.get_session(session.tmdb_session_id)
      assert found_session.id == session.id
    end

    test "get_session/1 returns error when session doesn't exist" do
      assert {:error, :not_found} = Auth.get_session("nonexistent")
    end

    test "create_session/1 with valid data creates a session" do
      assert {:ok, %Session{} = session} = Auth.create_session(@valid_attrs)
      assert session.tmdb_session_id == "session123"
      assert session.tmdb_user_id == 42
      assert session.username == "testuser"
      assert session.last_accessed_at != nil
    end

    test "create_session/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Auth.create_session(@invalid_attrs)
    end

    test "create_session/1 sets last_accessed_at automatically" do
      {:ok, session} = Auth.create_session(@valid_attrs)
      assert session.last_accessed_at != nil
    end

    test "update_last_accessed/1 updates the session's last_accessed_at" do
      {:ok, session} = Auth.create_session(@valid_attrs)
      original_time = session.last_accessed_at

      # Wait a moment to ensure time difference
      :timer.sleep(1100)

      {:ok, updated_session} = Auth.update_last_accessed(session)
      assert DateTime.compare(updated_session.last_accessed_at, original_time) == :gt
    end

    test "delete_session/1 deletes the session" do
      {:ok, session} = Auth.create_session(@valid_attrs)
      assert {:ok, %Session{}} = Auth.delete_session(session)
      assert {:error, :not_found} = Auth.get_session(session.tmdb_session_id)
    end

    test "delete_session_by_id/1 deletes the session by tmdb_session_id" do
      {:ok, session} = Auth.create_session(@valid_attrs)
      assert {:ok, %Session{}} = Auth.delete_session_by_id(session.tmdb_session_id)
      assert {:error, :not_found} = Auth.get_session(session.tmdb_session_id)
    end

    test "delete_session_by_id/1 returns error when session doesn't exist" do
      assert {:error, :not_found} = Auth.delete_session_by_id("nonexistent")
    end

    test "session_active?/1 returns true for non-expired session" do
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)
      {:ok, session} = Auth.create_session(Map.put(@valid_attrs, :expires_at, future_time))
      assert Auth.session_active?(session) == true
    end

    test "session_active?/1 returns false for expired session" do
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)

      # We need to bypass validation to create an expired session for testing
      session = %Session{
        tmdb_session_id: "expired_session",
        tmdb_user_id: 42,
        username: "testuser",
        expires_at: past_time,
        last_accessed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
      |> Flixir.Repo.insert!(skip_validation: true)

      assert Auth.session_active?(session) == false
    end

    test "cleanup_expired_sessions/0 removes expired sessions" do
      # Create an active session
      {:ok, _active_session} = Auth.create_session(@valid_attrs)

      # Create an expired session (bypass validation)
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)

      %Session{
        tmdb_session_id: "expired_session",
        tmdb_user_id: 42,
        username: "testuser",
        expires_at: past_time,
        last_accessed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
      |> Flixir.Repo.insert!(skip_validation: true)

      # Should have 2 sessions total
      assert length(Flixir.Repo.all(Session)) == 2

      # Cleanup expired sessions
      {deleted_count, _} = Auth.cleanup_expired_sessions()
      assert deleted_count == 1

      # Should have 1 session remaining
      assert length(Flixir.Repo.all(Session)) == 1
    end

    test "get_user_sessions/1 returns all sessions for a user" do
      user_id = 123
      attrs1 = Map.merge(@valid_attrs, %{tmdb_user_id: user_id, tmdb_session_id: "session1"})
      attrs2 = Map.merge(@valid_attrs, %{tmdb_user_id: user_id, tmdb_session_id: "session2"})
      attrs3 = Map.merge(@valid_attrs, %{tmdb_user_id: 456, tmdb_session_id: "session3"})

      {:ok, _session1} = Auth.create_session(attrs1)
      {:ok, _session2} = Auth.create_session(attrs2)
      {:ok, _session3} = Auth.create_session(attrs3)

      user_sessions = Auth.get_user_sessions(user_id)
      assert length(user_sessions) == 2
      assert Enum.all?(user_sessions, fn s -> s.tmdb_user_id == user_id end)
    end
  end
end
