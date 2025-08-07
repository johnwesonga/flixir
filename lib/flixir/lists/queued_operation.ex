defmodule Flixir.Lists.QueuedOperation do
  @moduledoc """
  Schema for queued list operations that need to be processed when TMDB API is available.

  Stores operations that failed due to API unavailability, network issues, or other
  temporary failures, allowing them to be retried later.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @operation_types ~w(create_list update_list delete_list clear_list add_movie remove_movie)
  @statuses ~w(pending processing completed failed cancelled)

  schema "queued_list_operations" do
    field :operation_type, :string
    field :tmdb_user_id, :integer
    field :tmdb_list_id, :integer
    field :operation_data, :map
    field :retry_count, :integer, default: 0
    field :last_retry_at, :utc_datetime
    field :status, :string, default: "pending"
    field :error_message, :string
    field :scheduled_for, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new queued operation.
  """
  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [
      :operation_type, :tmdb_user_id, :tmdb_list_id, :operation_data,
      :retry_count, :last_retry_at, :status, :error_message, :scheduled_for
    ])
    |> validate_required([:operation_type, :tmdb_user_id, :operation_data])
    |> validate_inclusion(:operation_type, @operation_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:retry_count, greater_than_or_equal_to: 0)
    |> validate_operation_data()
  end

  @doc """
  Creates a changeset for updating operation status and retry information.
  """
  def retry_changeset(operation, attrs) do
    operation
    |> cast(attrs, [:status, :retry_count, :last_retry_at, :error_message, :scheduled_for])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:retry_count, greater_than_or_equal_to: 0)
  end

  @doc """
  Returns the list of valid operation types.
  """
  def operation_types, do: @operation_types

  @doc """
  Returns the list of valid statuses.
  """
  def statuses, do: @statuses

  # Private functions

  defp validate_operation_data(changeset) do
    operation_type = get_field(changeset, :operation_type)
    operation_data = get_field(changeset, :operation_data)

    case {operation_type, operation_data} do
      {"create_list", %{"name" => name}} when is_binary(name) ->
        changeset

      {"update_list", %{"name" => name}} when is_binary(name) ->
        changeset

      {"delete_list", %{}} ->
        changeset

      {"clear_list", %{}} ->
        changeset

      {"add_movie", %{"movie_id" => movie_id}} when is_integer(movie_id) ->
        changeset

      {"remove_movie", %{"movie_id" => movie_id}} when is_integer(movie_id) ->
        changeset

      {nil, _} ->
        changeset

      _ ->
        add_error(changeset, :operation_data, "invalid data for operation type")
    end
  end
end
