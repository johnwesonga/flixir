defmodule Flixir.Reviews.Review do
  @moduledoc """
  Represents a review for a movie or TV show.

  Contains review content, author information, ratings, and metadata
  from external sources like TMDB.
  """

  @type t :: %__MODULE__{
    id: String.t(),
    author: String.t(),
    author_details: map(),
    content: String.t(),
    created_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil,
    url: String.t() | nil,
    rating: float() | nil
  }

  defstruct [
    :id,
    :author,
    :author_details,
    :content,
    :created_at,
    :updated_at,
    :url,
    :rating
  ]

  @doc """
  Creates a new Review struct from a map of attributes.

  ## Examples

      iex> Flixir.Reviews.Review.new(%{
      ...>   id: "123",
      ...>   author: "John Doe",
      ...>   content: "Great movie!"
      ...> })
      {:ok, %Flixir.Reviews.Review{id: "123", author: "John Doe", content: "Great movie!"}}

      iex> Flixir.Reviews.Review.new(%{})
      {:error, :missing_required_fields}
  """
  def new(attrs) when is_map(attrs) do
    case validate_required_fields(attrs) do
      :ok ->
        review = %__MODULE__{
          id: Map.get(attrs, :id) || Map.get(attrs, "id"),
          author: Map.get(attrs, :author) || Map.get(attrs, "author"),
          author_details: Map.get(attrs, :author_details) || Map.get(attrs, "author_details") || %{},
          content: Map.get(attrs, :content) || Map.get(attrs, "content"),
          created_at: parse_datetime(Map.get(attrs, :created_at) || Map.get(attrs, "created_at")),
          updated_at: parse_datetime(Map.get(attrs, :updated_at) || Map.get(attrs, "updated_at")),
          url: Map.get(attrs, :url) || Map.get(attrs, "url"),
          rating: parse_rating(Map.get(attrs, :rating) || Map.get(attrs, "rating"))
        }
        {:ok, review}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates that a review struct has all required fields populated.

  ## Examples

      iex> review = %Flixir.Reviews.Review{id: "123", author: "John", content: "Good"}
      iex> Flixir.Reviews.Review.valid?(review)
      true

      iex> review = %Flixir.Reviews.Review{id: nil, author: "John", content: "Good"}
      iex> Flixir.Reviews.Review.valid?(review)
      false
  """
  def valid?(%__MODULE__{} = review) do
    not is_nil(review.id) and
    not is_nil(review.author) and
    not is_nil(review.content) and
    String.trim(review.author) != "" and
    String.trim(review.content) != ""
  end

  @doc """
  Truncates review content to a specified length for display purposes.

  ## Examples

      iex> review = %Flixir.Reviews.Review{content: "This is a very long review content"}
      iex> Flixir.Reviews.Review.truncate_content(review, 10)
      "This is a..."
  """
  def truncate_content(%__MODULE__{content: content}, max_length) when is_integer(max_length) do
    if String.length(content) <= max_length do
      content
    else
      String.slice(content, 0, max_length) <> "..."
    end
  end

  # Private functions

  defp validate_required_fields(attrs) do
    required_fields = [:id, :author, :content]

    missing_fields = Enum.filter(required_fields, fn field ->
      value = Map.get(attrs, field) || Map.get(attrs, to_string(field))
      is_nil(value) or (is_binary(value) and String.trim(value) == "")
    end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, {:missing_required_fields, missing_fields}}
    end
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _reason} -> nil
    end
  end
  defp parse_datetime(%DateTime{} = datetime), do: datetime
  defp parse_datetime(_), do: nil

  defp parse_rating(nil), do: nil
  defp parse_rating(rating) when is_number(rating) and rating >= 0 and rating <= 10, do: rating
  defp parse_rating(rating) when is_binary(rating) do
    case Float.parse(rating) do
      {parsed_rating, _} when parsed_rating >= 0 and parsed_rating <= 10 -> parsed_rating
      _ -> nil
    end
  end
  defp parse_rating(_), do: nil
end
