defmodule Flixir.Auth.SessionTest do
  use Flixir.DataCase

  alias Flixir.Auth.Session

  describe "changeset/2" do
    @valid_attrs %{
      tmdb_session_id: "session123",
      tmdb_user_id: 42,
      username: "testuser",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)
    }

    test "changeset with valid attributes" do
      changeset = Session.changeset(%Session{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset requires tmdb_session_id" do
      attrs = Map.delete(@valid_attrs, :tmdb_session_id)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{tmdb_session_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "changeset requires tmdb_user_id" do
      attrs = Map.delete(@valid_attrs, :tmdb_user_id)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{tmdb_user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "changeset requires username" do
      attrs = Map.delete(@valid_attrs, :username)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "changeset requires expires_at" do
      attrs = Map.delete(@valid_attrs, :expires_at)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{expires_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "changeset validates tmdb_session_id length" do
      attrs = Map.put(@valid_attrs, :tmdb_session_id, "")
      changeset = Session.changeset(%Session{}, attrs)
      assert %{tmdb_session_id: ["can't be blank"]} = errors_on(changeset)

      long_string = String.duplicate("a", 256)
      attrs = Map.put(@valid_attrs, :tmdb_session_id, long_string)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{tmdb_session_id: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "changeset validates username length" do
      attrs = Map.put(@valid_attrs, :username, "")
      changeset = Session.changeset(%Session{}, attrs)
      assert %{username: ["can't be blank"]} = errors_on(changeset)

      long_string = String.duplicate("a", 256)
      attrs = Map.put(@valid_attrs, :username, long_string)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{username: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "changeset validates tmdb_user_id is positive" do
      attrs = Map.put(@valid_attrs, :tmdb_user_id, 0)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{tmdb_user_id: ["must be greater than 0"]} = errors_on(changeset)

      attrs = Map.put(@valid_attrs, :tmdb_user_id, -1)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{tmdb_user_id: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "changeset validates expires_at is in the future" do
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)
      attrs = Map.put(@valid_attrs, :expires_at, past_time)
      changeset = Session.changeset(%Session{}, attrs)
      assert %{expires_at: ["must be in the future"]} = errors_on(changeset)
    end

    test "changeset sets last_accessed_at automatically when not provided" do
      changeset = Session.changeset(%Session{}, @valid_attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :last_accessed_at) != nil
    end

    test "changeset preserves last_accessed_at when provided" do
      specific_time =
        DateTime.add(DateTime.utc_now(), -1800, :second) |> DateTime.truncate(:second)

      attrs = Map.put(@valid_attrs, :last_accessed_at, specific_time)
      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :last_accessed_at) == specific_time
    end
  end

  describe "update_last_accessed_changeset/1" do
    test "updates last_accessed_at to current time" do
      session = %Session{
        last_accessed_at:
          DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)
      }

      changeset = Session.update_last_accessed_changeset(session)

      new_time = Ecto.Changeset.get_change(changeset, :last_accessed_at)
      assert new_time != nil
      assert DateTime.diff(DateTime.utc_now(), new_time, :second) < 2
    end
  end
end
