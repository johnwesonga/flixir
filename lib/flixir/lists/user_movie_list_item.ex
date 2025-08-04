defmodule Flixir.Lists.UserMovieListItem do
  @moduledoc """
  Schema for items in user movie lists.

  Represents the junction table between user movie lists and movies,
  storing the TMDB movie ID and when it was added to the list.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_movie_list_items" do
    field :tmdb_movie_id, :integer
    field :added_at, :utc_datetime

    belongs_to :list, Flixir.Lists.UserMovieList, foreign_key: :list_id, type: :binary_id

    timestamps(updated_at: false)
  end

  @doc """
  Creates a changeset for a user movie list item.

  ## Validations
  - tmdb_movie_id: required, positive integer
  - list_id: required (via belongs_to association)
  - added_at: automatically set to current UTC time if not provided

  ## Constraints
  - Unique constraint on [list_id, tmdb_movie_id] to prevent duplicate movies in same list
  """
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:tmdb_movie_id, :list_id, :added_at])
    |> validate_required([:tmdb_movie_id, :list_id])
    |> validate_number(:tmdb_movie_id, greater_than: 0)
    |> maybe_set_added_at()
    |> unique_constraint([:list_id, :tmdb_movie_id],
         name: :idx_unique_movie_per_list,
         message: "Movie is already in this list")
  end

  @doc """
  Creates a changeset for adding a movie to a list.

  Simplified changeset that only requires the movie ID and list association.
  """
  def add_movie_changeset(item, attrs) do
    item
    |> cast(attrs, [:tmdb_movie_id, :list_id])
    |> validate_required([:tmdb_movie_id, :list_id])
    |> validate_number(:tmdb_movie_id, greater_than: 0)
    |> maybe_set_added_at()
    |> unique_constraint([:list_id, :tmdb_movie_id],
         name: :idx_unique_movie_per_list,
         message: "Movie is already in this list")
  end

  # Private function to set added_at timestamp if not provided
  defp maybe_set_added_at(changeset) do
    case get_field(changeset, :added_at) do
      nil ->
        put_change(changeset, :added_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ ->
        changeset
    end
  end
end
