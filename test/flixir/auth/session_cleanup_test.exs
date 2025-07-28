defmodule Flixir.Auth.SessionCleanupTest do
  use Flixir.DataCase, async: false

  import Ecto.Query

  alias Flixir.Auth
  alias Flixir.Auth.SessionCleanup

  describe "session cleanup" do
    test "cleanup_expired_sessions/0 removes expired sessions" do
      # Create a valid session
      valid_session_attrs = %{
        tmdb_session_id: "valid_session_123",
        tmdb_user_id: 12345,
        username: "testuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      {:ok, valid_session} = Auth.create_session(valid_session_attrs)

      # Create a session that will expire soon, then manually update it to be expired
      soon_expired_attrs = %{
        tmdb_session_id: "expired_session_456",
        tmdb_user_id: 67890,
        username: "expireduser",
        expires_at: DateTime.add(DateTime.utc_now(), 1, :second)  # Expires in 1 second
      }

      {:ok, expired_session} = Auth.create_session(soon_expired_attrs)

      # Wait for it to expire, then manually update the database
      :timer.sleep(1100)  # Wait 1.1 seconds

      # Manually update the session to be expired in the database
      from(s in Flixir.Auth.Session, where: s.id == ^expired_session.id)
      |> Flixir.Repo.update_all(set: [expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)])

      # Cleanup should remove only the expired session
      {:ok, count} = SessionCleanup.cleanup_expired_sessions()
      assert count == 1

      # Valid session should still exist
      assert {:ok, _session} = Auth.get_session("valid_session_123")

      # Expired session should be gone
      assert {:error, :not_found} = Auth.get_session("expired_session_456")
    end

    test "cleanup_expired_sessions/0 removes idle sessions" do
      # Create a session that's not expired but will be idle
      idle_session_attrs = %{
        tmdb_session_id: "idle_session_789",
        tmdb_user_id: 11111,
        username: "idleuser",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      {:ok, idle_session} = Auth.create_session(idle_session_attrs)

      # Manually update the session to be idle (last accessed more than 2 hours ago)
      from(s in Flixir.Auth.Session, where: s.id == ^idle_session.id)
      |> Flixir.Repo.update_all(set: [last_accessed_at: DateTime.add(DateTime.utc_now(), -7300, :second)])

      # Cleanup should remove the idle session
      {:ok, count} = SessionCleanup.cleanup_expired_sessions()
      assert count == 1

      # Idle session should be gone
      assert {:error, :not_found} = Auth.get_session("idle_session_789")
    end

    test "get_stats/0 returns cleanup statistics" do
      stats = SessionCleanup.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :last_cleanup_at)
      assert Map.has_key?(stats, :total_cleanups)
      assert Map.has_key?(stats, :total_sessions_cleaned)
      assert Map.has_key?(stats, :last_cleanup_count)
    end
  end
end
