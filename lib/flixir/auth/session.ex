defmodule Flixir.Auth.Session do
  @moduledoc """
  Schema for TMDB authentication sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "auth_sessions" do
    field :tmdb_session_id, :string
    field :tmdb_user_id, :integer
    field :username, :string
    field :expires_at, :utc_datetime
    field :last_accessed_at, :utc_datetime

    timestamps()
  end

  @doc """
  Changeset for creating and updating sessions.
  """
  def changeset(session, attrs) do
    session
    |> cast(attrs, [:tmdb_session_id, :tmdb_user_id, :username, :expires_at, :last_accessed_at])
    |> validate_required([:tmdb_session_id, :tmdb_user_id, :username, :expires_at])
    |> validate_length(:tmdb_session_id, min: 1, max: 255)
    |> validate_length(:username, min: 1, max: 255)
    |> validate_number(:tmdb_user_id, greater_than: 0)
    |> validate_expires_at()
    |> unique_constraint(:tmdb_session_id)
    |> maybe_set_last_accessed()
  end

  @doc """
  Changeset for updating only the last accessed time.
  """
  def update_last_accessed_changeset(session) do
    session
    |> change(last_accessed_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  # Private functions

  defp validate_expires_at(changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        changeset

      expires_at ->
        now = DateTime.utc_now()

        if DateTime.compare(expires_at, now) == :gt do
          changeset
        else
          add_error(changeset, :expires_at, "must be in the future")
        end
    end
  end

  defp maybe_set_last_accessed(changeset) do
    case get_field(changeset, :last_accessed_at) do
      nil -> put_change(changeset, :last_accessed_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
