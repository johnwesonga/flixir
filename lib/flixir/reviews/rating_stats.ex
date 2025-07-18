defmodule Flixir.Reviews.RatingStats do
  @moduledoc """
  Represents aggregated rating statistics for a movie or TV show.

  Contains average ratings, total review counts, and rating distribution
  data to provide users with quick insights into content reception.
  """

  @type t :: %__MODULE__{
    average_rating: float() | nil,
    total_reviews: integer(),
    rating_distribution: map(),
    source: String.t()
  }

  defstruct [
    :average_rating,
    total_reviews: 0,
    rating_distribution: %{},
    source: "tmdb"
  ]

  @doc """
  Creates a new RatingStats struct from a map of attributes.

  ## Examples

      iex> Flixir.Reviews.RatingStats.new(%{
      ...>   average_rating: 7.5,
      ...>   total_reviews: 100,
      ...>   rating_distribution: %{"5" => 10, "4" => 20}
      ...> })
      {:ok, %Flixir.Reviews.RatingStats{average_rating: 7.5, total_reviews: 100}}

      iex> Flixir.Reviews.RatingStats.new(%{total_reviews: -1})
      {:error, :invalid_total_reviews}
  """
  def new(attrs) when is_map(attrs) do
    case validate_attrs(attrs) do
      :ok ->
        stats = %__MODULE__{
          average_rating: parse_rating(Map.get(attrs, :average_rating) || Map.get(attrs, "average_rating")),
          total_reviews: Map.get(attrs, :total_reviews) || Map.get(attrs, "total_reviews") || 0,
          rating_distribution: Map.get(attrs, :rating_distribution) || Map.get(attrs, "rating_distribution") || %{},
          source: Map.get(attrs, :source) || Map.get(attrs, "source") || "tmdb"
        }
        {:ok, stats}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates that rating stats have valid values.

  ## Examples

      iex> stats = %Flixir.Reviews.RatingStats{average_rating: 7.5, total_reviews: 10}
      iex> Flixir.Reviews.RatingStats.valid?(stats)
      true

      iex> stats = %Flixir.Reviews.RatingStats{average_rating: 15.0, total_reviews: 10}
      iex> Flixir.Reviews.RatingStats.valid?(stats)
      false
  """
  def valid?(%__MODULE__{} = stats) do
    valid_average_rating?(stats.average_rating) and
    valid_total_reviews?(stats.total_reviews) and
    valid_rating_distribution?(stats.rating_distribution)
  end

  @doc """
  Calculates rating distribution percentages from raw counts.

  ## Examples

      iex> stats = %Flixir.Reviews.RatingStats{
      ...>   total_reviews: 100,
      ...>   rating_distribution: %{"5" => 50, "4" => 30, "3" => 20}
      ...> }
      iex> Flixir.Reviews.RatingStats.rating_percentages(stats)
      %{"5" => 50.0, "4" => 30.0, "3" => 20.0}
  """
  def rating_percentages(%__MODULE__{total_reviews: 0}), do: %{}
  def rating_percentages(%__MODULE__{total_reviews: total, rating_distribution: distribution}) do
    Enum.into(distribution, %{}, fn {rating, count} ->
      percentage = (count / total) * 100
      {rating, Float.round(percentage, 1)}
    end)
  end

  @doc """
  Returns a formatted string representation of the average rating.

  ## Examples

      iex> stats = %Flixir.Reviews.RatingStats{average_rating: 7.85}
      iex> Flixir.Reviews.RatingStats.formatted_average(stats)
      "7.9"

      iex> stats = %Flixir.Reviews.RatingStats{average_rating: nil}
      iex> Flixir.Reviews.RatingStats.formatted_average(stats)
      "N/A"
  """
  def formatted_average(%__MODULE__{average_rating: nil}), do: "N/A"
  def formatted_average(%__MODULE__{average_rating: rating}) do
    Float.round(rating, 1) |> to_string()
  end

  @doc """
  Merges multiple rating stats from different sources.

  ## Examples

      iex> stats1 = %Flixir.Reviews.RatingStats{total_reviews: 50, average_rating: 7.0}
      iex> stats2 = %Flixir.Reviews.RatingStats{total_reviews: 30, average_rating: 8.0}
      iex> Flixir.Reviews.RatingStats.merge([stats1, stats2])
      %Flixir.Reviews.RatingStats{total_reviews: 80, average_rating: 7.375}
  """
  def merge([]), do: %__MODULE__{}
  def merge([single_stats]), do: single_stats
  def merge(stats_list) when is_list(stats_list) do
    total_reviews = Enum.sum(Enum.map(stats_list, & &1.total_reviews))

    weighted_average = if total_reviews > 0 do
      weighted_sum = Enum.reduce(stats_list, 0, fn stats, acc ->
        if stats.average_rating do
          acc + (stats.average_rating * stats.total_reviews)
        else
          acc
        end
      end)
      weighted_sum / total_reviews
    else
      nil
    end

    merged_distribution = Enum.reduce(stats_list, %{}, fn stats, acc ->
      Map.merge(acc, stats.rating_distribution, fn _key, v1, v2 -> v1 + v2 end)
    end)

    %__MODULE__{
      average_rating: weighted_average,
      total_reviews: total_reviews,
      rating_distribution: merged_distribution,
      source: "merged"
    }
  end

  # Private functions

  defp validate_attrs(attrs) do
    with :ok <- validate_total_reviews(Map.get(attrs, :total_reviews) || Map.get(attrs, "total_reviews")),
         :ok <- validate_average_rating(Map.get(attrs, :average_rating) || Map.get(attrs, "average_rating")) do
      :ok
    end
  end

  defp validate_total_reviews(nil), do: :ok
  defp validate_total_reviews(total) when is_integer(total) and total >= 0, do: :ok
  defp validate_total_reviews(_), do: {:error, :invalid_total_reviews}

  defp validate_average_rating(nil), do: :ok
  defp validate_average_rating(rating) when is_number(rating) and rating >= 0 and rating <= 10, do: :ok
  defp validate_average_rating(rating) when is_binary(rating) do
    case Float.parse(rating) do
      {parsed_rating, _} when parsed_rating >= 0 and parsed_rating <= 10 -> :ok
      _ -> {:error, :invalid_average_rating}
    end
  end
  defp validate_average_rating(_), do: {:error, :invalid_average_rating}

  defp valid_average_rating?(nil), do: true
  defp valid_average_rating?(rating) when is_number(rating), do: rating >= 0 and rating <= 10
  defp valid_average_rating?(_), do: false

  defp valid_total_reviews?(total) when is_integer(total), do: total >= 0
  defp valid_total_reviews?(_), do: false

  defp valid_rating_distribution?(distribution) when is_map(distribution), do: true
  defp valid_rating_distribution?(_), do: false

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
