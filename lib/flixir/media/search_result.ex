defmodule Flixir.Media.SearchResult do
  @moduledoc """
  Represents a search result from TMDB API for movies and TV shows.
  """

  @type t :: %__MODULE__{
    id: integer(),
    title: String.t(),
    media_type: :movie | :tv,
    release_date: Date.t() | nil,
    overview: String.t() | nil,
    poster_path: String.t() | nil,
    genre_ids: [integer()],
    vote_average: float(),
    popularity: float()
  }

  defstruct [
    :id,
    :title,
    :media_type,
    :release_date,
    :overview,
    :poster_path,
    :genre_ids,
    :vote_average,
    :popularity
  ]

  @doc """
  Creates a new SearchResult from TMDB API response data.
  """
  @spec from_tmdb_data(map()) :: {:ok, t()} | {:error, String.t()}
  def from_tmdb_data(data) when is_map(data) do
    with {:ok, validated_data} <- validate_tmdb_data(data) do
      result = %__MODULE__{
        id: validated_data["id"],
        title: get_title(validated_data),
        media_type: parse_media_type(validated_data["media_type"]),
        release_date: parse_date(get_release_date(validated_data)),
        overview: validated_data["overview"],
        poster_path: validated_data["poster_path"],
        genre_ids: validated_data["genre_ids"] || [],
        vote_average: validated_data["vote_average"] || 0.0,
        popularity: validated_data["popularity"] || 0.0
      }
      {:ok, result}
    end
  end

  def from_tmdb_data(_), do: {:error, "Invalid data format"}

  # Private helper functions

  defp validate_tmdb_data(data) do
    required_fields = ["id", "media_type"]

    case Enum.all?(required_fields, &Map.has_key?(data, &1)) do
      true -> {:ok, data}
      false -> {:error, "Missing required fields: #{inspect(required_fields)}"}
    end
  end

  defp get_title(%{"title" => title}) when is_binary(title), do: title
  defp get_title(%{"name" => name}) when is_binary(name), do: name
  defp get_title(_), do: "Unknown Title"

  defp get_release_date(%{"release_date" => date}) when is_binary(date), do: date
  defp get_release_date(%{"first_air_date" => date}) when is_binary(date), do: date
  defp get_release_date(_), do: nil

  defp parse_media_type("movie"), do: :movie
  defp parse_media_type("tv"), do: :tv
  defp parse_media_type(_), do: :movie

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(_), do: nil
end
