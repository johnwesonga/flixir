defmodule Flixir.Repo.Migrations.CreateUserMovieLists do
  use Ecto.Migration

  def change do
    create table(:user_movie_lists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, size: 100, null: false
      add :description, :text
      add :is_public, :boolean, default: false, null: false
      add :tmdb_user_id, :integer, null: false

      timestamps()
    end

    # Index for finding lists by user
    create index(:user_movie_lists, [:tmdb_user_id])

    # Index for ordering lists by last updated
    create index(:user_movie_lists, [:updated_at])

    # Composite index for user + updated_at for efficient user list queries
    create index(:user_movie_lists, [:tmdb_user_id, :updated_at])
  end
end
