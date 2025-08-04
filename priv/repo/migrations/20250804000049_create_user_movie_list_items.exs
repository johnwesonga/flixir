defmodule Flixir.Repo.Migrations.CreateUserMovieListItems do
  use Ecto.Migration

  def change do
    create table(:user_movie_list_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :list_id, references(:user_movie_lists, type: :binary_id, on_delete: :delete_all), null: false
      add :tmdb_movie_id, :integer, null: false
      add :added_at, :utc_datetime, null: false

      timestamps(updated_at: false)
    end

    # Index for finding items by list
    create index(:user_movie_list_items, [:list_id])

    # Index for finding lists containing a specific movie
    create index(:user_movie_list_items, [:tmdb_movie_id])

    # Unique constraint to prevent duplicate movies per list
    create unique_index(:user_movie_list_items, [:list_id, :tmdb_movie_id],
                       name: :idx_unique_movie_per_list)

    # Index for ordering items by when they were added
    create index(:user_movie_list_items, [:added_at])
  end
end
