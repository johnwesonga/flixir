defmodule Flixir.Repo.Migrations.CreateAuthSessions do
  use Ecto.Migration

  def change do
    create table(:auth_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tmdb_session_id, :string, null: false
      add :tmdb_user_id, :integer, null: false
      add :username, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :last_accessed_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:auth_sessions, [:tmdb_session_id])
    create index(:auth_sessions, [:expires_at])
    create index(:auth_sessions, [:tmdb_user_id])
  end
end
