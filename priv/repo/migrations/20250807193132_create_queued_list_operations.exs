defmodule Flixir.Repo.Migrations.CreateQueuedListOperations do
  use Ecto.Migration

  def change do
    create table(:queued_list_operations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :operation_type, :string, null: false
      add :tmdb_user_id, :integer, null: false
      add :tmdb_list_id, :integer
      add :operation_data, :map, null: false
      add :retry_count, :integer, default: 0
      add :last_retry_at, :utc_datetime
      add :status, :string, default: "pending"
      add :error_message, :text
      add :scheduled_for, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:queued_list_operations, [:status, :inserted_at])
    create index(:queued_list_operations, [:tmdb_user_id])
    create index(:queued_list_operations, [:scheduled_for])
    create index(:queued_list_operations, [:operation_type, :tmdb_list_id, :status])
  end
end
