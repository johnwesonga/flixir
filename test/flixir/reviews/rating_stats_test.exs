defmodule Flixir.Reviews.RatingStatsTest do
  use ExUnit.Case, async: true

  alias Flixir.Reviews.RatingStats

  describe "new/1" do
    test "creates rating stats with valid attributes" do
      attrs = %{
        average_rating: 7.5,
        total_reviews: 100,
        rating_distribution: %{"5" => 20, "4" => 30, "3" => 25, "2" => 15, "1" => 10}
      }

      assert {:ok, stats} = RatingStats.new(attrs)
      assert stats.average_rating == 7.5
      assert stats.total_reviews == 100
      assert stats.rating_distribution == %{"5" => 20, "4" => 30, "3" => 25, "2" => 15, "1" => 10}
      assert stats.source == "tmdb"
    end

    test "creates rating stats with string keys" do
      attrs = %{
        "average_rating" => "8.2",
        "total_reviews" => 50,
        "source" => "imdb"
      }

      assert {:ok, stats} = RatingStats.new(attrs)
      assert stats.average_rating == 8.2
      assert stats.total_reviews == 50
      assert stats.source == "imdb"
    end

    test "handles missing optional fields" do
      attrs = %{total_reviews: 10}

      assert {:ok, stats} = RatingStats.new(attrs)
      assert is_nil(stats.average_rating)
      assert stats.total_reviews == 10
      assert stats.rating_distribution == %{}
      assert stats.source == "tmdb"
    end

    test "validates total_reviews" do
      # Valid total_reviews
      assert {:ok, _} = RatingStats.new(%{total_reviews: 0})
      assert {:ok, _} = RatingStats.new(%{total_reviews: 100})

      # Invalid total_reviews
      assert {:error, :invalid_total_reviews} = RatingStats.new(%{total_reviews: -1})
      assert {:error, :invalid_total_reviews} = RatingStats.new(%{total_reviews: "invalid"})
    end

    test "validates average_rating" do
      # Valid ratings
      assert {:ok, _} = RatingStats.new(%{average_rating: 0})
      assert {:ok, _} = RatingStats.new(%{average_rating: 5.5})
      assert {:ok, _} = RatingStats.new(%{average_rating: 10})

      # Invalid ratings
      assert {:error, :invalid_average_rating} = RatingStats.new(%{average_rating: -1})
      assert {:error, :invalid_average_rating} = RatingStats.new(%{average_rating: 11})
      assert {:error, :invalid_average_rating} = RatingStats.new(%{average_rating: "invalid"})
    end
  end

  describe "valid?/1" do
    test "returns true for valid stats" do
      stats = %RatingStats{
        average_rating: 7.5,
        total_reviews: 100,
        rating_distribution: %{"5" => 20}
      }

      assert RatingStats.valid?(stats)
    end

    test "returns true for stats with nil average_rating" do
      stats = %RatingStats{
        average_rating: nil,
        total_reviews: 0,
        rating_distribution: %{}
      }

      assert RatingStats.valid?(stats)
    end

    test "returns false for invalid stats" do
      # Invalid average_rating
      stats = %RatingStats{average_rating: -1, total_reviews: 10}
      refute RatingStats.valid?(stats)

      stats = %RatingStats{average_rating: 15, total_reviews: 10}
      refute RatingStats.valid?(stats)

      # Invalid total_reviews
      stats = %RatingStats{average_rating: 7.5, total_reviews: -5}
      refute RatingStats.valid?(stats)

      # Invalid rating_distribution
      stats = %RatingStats{average_rating: 7.5, total_reviews: 10, rating_distribution: "invalid"}
      refute RatingStats.valid?(stats)
    end
  end

  describe "rating_percentages/1" do
    test "calculates percentages correctly" do
      stats = %RatingStats{
        total_reviews: 100,
        rating_distribution: %{"5" => 50, "4" => 30, "3" => 20}
      }

      percentages = RatingStats.rating_percentages(stats)
      assert percentages == %{"5" => 50.0, "4" => 30.0, "3" => 20.0}
    end

    test "handles zero total reviews" do
      stats = %RatingStats{total_reviews: 0, rating_distribution: %{"5" => 10}}

      percentages = RatingStats.rating_percentages(stats)
      assert percentages == %{}
    end

    test "rounds percentages to one decimal place" do
      stats = %RatingStats{
        total_reviews: 3,
        rating_distribution: %{"5" => 1, "4" => 1, "3" => 1}
      }

      percentages = RatingStats.rating_percentages(stats)
      assert percentages["5"] == 33.3
      assert percentages["4"] == 33.3
      assert percentages["3"] == 33.3
    end
  end

  describe "formatted_average/1" do
    test "formats average rating to one decimal place" do
      stats = %RatingStats{average_rating: 7.85}
      assert RatingStats.formatted_average(stats) == "7.8"

      stats = %RatingStats{average_rating: 8.0}
      assert RatingStats.formatted_average(stats) == "8.0"
    end

    test "returns N/A for nil average rating" do
      stats = %RatingStats{average_rating: nil}
      assert RatingStats.formatted_average(stats) == "N/A"
    end
  end

  describe "merge/1" do
    test "merges multiple rating stats" do
      stats1 = %RatingStats{
        total_reviews: 50,
        average_rating: 7.0,
        rating_distribution: %{"5" => 10, "4" => 20}
      }

      stats2 = %RatingStats{
        total_reviews: 30,
        average_rating: 8.0,
        rating_distribution: %{"5" => 15, "3" => 10}
      }

      merged = RatingStats.merge([stats1, stats2])

      assert merged.total_reviews == 80
      assert_in_delta merged.average_rating, 7.375, 0.001  # (7.0*50 + 8.0*30) / 80
      assert merged.rating_distribution == %{"5" => 25, "4" => 20, "3" => 10}
      assert merged.source == "merged"
    end

    test "handles empty list" do
      merged = RatingStats.merge([])
      assert merged == %RatingStats{}
    end

    test "returns single stats unchanged" do
      stats = %RatingStats{total_reviews: 10, average_rating: 7.5}
      merged = RatingStats.merge([stats])
      assert merged == stats
    end

    test "handles stats with nil average_rating" do
      stats1 = %RatingStats{total_reviews: 50, average_rating: 7.0}
      stats2 = %RatingStats{total_reviews: 30, average_rating: nil}

      merged = RatingStats.merge([stats1, stats2])

      assert merged.total_reviews == 80
      assert_in_delta merged.average_rating, 4.375, 0.001  # (7.0*50 + 0*30) / 80
    end

    test "handles all stats with nil average_rating" do
      stats1 = %RatingStats{total_reviews: 50, average_rating: nil}
      stats2 = %RatingStats{total_reviews: 30, average_rating: nil}

      merged = RatingStats.merge([stats1, stats2])

      assert merged.total_reviews == 80
      assert merged.average_rating == 0.0
    end
  end
end
