defmodule Flixir.Lists.UserMovieList do
  @moduledoc """
  Schema for user movie lists.

  Represents a user-created movie list with name, description, privacy settings,
  and association to the user via their TMDB user ID.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_movie_lists" do
    field :name, :string
    field :description, :string
    field :is_public, :boolean, default: false
    field :tmdb_user_id, :integer

    has_many :list_items, Flixir.Lists.UserMovieListItem,
      foreign_key: :list_id,
      on_delete: :delete_all

    has_many :movies, through: [:list_items, :movie]

    timestamps()
  end

  @doc """
  Creates a changeset for a user movie list.

  ## Validations
  - name: required, 3-100 characters
  - description: optional, max 500 characters
  - tmdb_user_id: required, positive integer
  - is_public: boolean, defaults to false
  """
  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :description, :is_public, :tmdb_user_id])
    |> validate_required([:name, :tmdb_user_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:tmdb_user_id, greater_than: 0)
    |> validate_inclusion(:is_public, [true, false])
  end

  @doc """
  Creates a changeset for updating a user movie list.

  Similar to changeset/2 but doesn't require tmdb_user_id since it shouldn't change.
  """
  def update_changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :description, :is_public])
    |> validate_required([:name])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:is_public, [true, false])
  end
end
