defmodule FlixirWeb.ReviewComponentsTest do
  use FlixirWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FlixirWeb.ReviewComponents

  alias Flixir.Reviews.Review
  alias Flixir.Reviews.RatingStats

  describe "review_card/1" do
    test "renders basic review card with all elements" do
      review = %Review{
        id: "123",
        author: "John Doe",
        content: "This is a great movie with excellent acting and cinematography.",
        rating: 8.5,
        created_at: ~U[2024-01-15 10:30:00Z],
        url: "https://example.com/review/123"
      }

      html = render_component(&review_card/1, review: review)

      assert html =~ "review-card"
      assert html =~ "John Doe"
      assert html =~ "This is a great movie"
      assert html =~ "8.5"
      assert html =~ "View original review"
      assert html =~ "https://example.com/review/123"
    end

    test "renders review without rating" do
      review = %Review{
        id: "124",
        author: "Jane Smith",
        content: "Interesting plot but could be better.",
        rating: nil,
        created_at: ~U[2024-01-15 10:30:00Z]
      }

      html = render_component(&review_card/1, review: review)

      assert html =~ "Jane Smith"
      assert html =~ "Interesting plot"
      refute html =~ "star-solid"
      refute html =~ "rating"
    end

    test "renders review without created_at date" do
      review = %Review{
        id: "125",
        author: "Bob Wilson",
        content: "Amazing cinematography!",
        rating: 9.0,
        created_at: nil
      }

      html = render_component(&review_card/1, review: review)

      assert html =~ "Bob Wilson"
      assert html =~ "Amazing cinematography"
      refute html =~ "<time"
    end

    test "renders truncated content with read more button for long reviews" do
      long_content = String.duplicate("This is a very long review content. ", 20)

      review = %Review{
        id: "126",
        author: "Alice Brown",
        content: long_content,
        rating: 7.0
      }

      html = render_component(&review_card/1, review: review, expanded: false)

      assert html =~ "read-more-button"
      assert html =~ "Read more"
      refute html =~ "Show less"
    end

    test "renders full content with show less button when expanded" do
      long_content = String.duplicate("This is a very long review content. ", 20)

      review = %Review{
        id: "127",
        author: "Charlie Davis",
        content: long_content,
        rating: 6.5
      }

      html = render_component(&review_card/1, review: review, expanded: true)

      assert html =~ "show-less-button"
      assert html =~ "Show less"
      refute html =~ "Read more"
    end

    test "renders spoiler warning when review contains spoilers and spoilers are hidden" do
      review = %Review{
        id: "128",
        author: "Diana Evans",
        content: "Great movie but the ending where the main character dies was unexpected.",
        rating: 8.0
      }

      html = render_component(&review_card/1, review: review, show_spoilers: false)

      assert html =~ "Spoiler Warning"
      assert html =~ "reveal-spoilers-button"
      assert html =~ "Show spoilers anyway"
      refute html =~ "main character dies"
    end

    test "renders full content when spoilers are revealed" do
      review = %Review{
        id: "129",
        author: "Frank Green",
        content: "The plot twist at the ending was amazing when the secret was revealed.",
        rating: 9.5
      }

      html = render_component(&review_card/1, review: review, show_spoilers: true)

      assert html =~ "plot twist at the ending"
      assert html =~ "secret was revealed"
      refute html =~ "Spoiler Warning"
    end

    test "renders author avatar with first letter" do
      review = %Review{
        id: "130",
        author: "George Harris",
        content: "Good movie overall.",
        rating: 7.5
      }

      html = render_component(&review_card/1, review: review)

      assert html =~ "G"
      assert html =~ "bg-gradient-to-br from-blue-500 to-purple-600"
    end

    test "formats review date correctly" do
      yesterday = DateTime.add(DateTime.utc_now(), -1, :day)

      review = %Review{
        id: "131",
        author: "Helen Jones",
        content: "Recent review.",
        created_at: yesterday
      }

      html = render_component(&review_card/1, review: review)

      assert html =~ "Yesterday"
    end

    test "renders without footer when no URL provided" do
      review = %Review{
        id: "132",
        author: "Ian King",
        content: "No external link review.",
        url: nil
      }

      html = render_component(&review_card/1, review: review)

      refute html =~ "View original review"
      refute html =~ "border-t border-gray-100"
    end
  end

  describe "spoiler_warning/1" do
    test "renders spoiler warning with correct elements" do
      html = render_component(&spoiler_warning/1, review_id: "test-123")

      assert html =~ "Spoiler Warning"
      assert html =~ "This review may contain spoilers"
      assert html =~ "reveal-spoilers-button"
      assert html =~ "Show spoilers anyway"
      assert html =~ "hero-exclamation-triangle"
    end

    test "includes review ID in button event" do
      html = render_component(&spoiler_warning/1, review_id: "review-456")

      assert html =~ "reveal_spoilers"
      assert html =~ "review-456"
    end
  end

  describe "rating_display/1" do
    test "renders compact rating display with rating" do
      stats = %RatingStats{
        average_rating: 8.2,
        total_reviews: 150,
        rating_distribution: %{"8" => 50, "9" => 30, "7" => 70},
        source: "tmdb"
      }

      html = render_component(&rating_display/1, stats: stats, compact: true)

      assert html =~ "rating-display"
      assert html =~ "8.2"
      assert html =~ "150 reviews"
      assert html =~ "tmdb"
      assert html =~ "hero-star-solid"
    end

    test "renders compact rating display without rating" do
      stats = %RatingStats{
        average_rating: nil,
        total_reviews: 25,
        rating_distribution: %{},
        source: "tmdb"
      }

      html = render_component(&rating_display/1, stats: stats, compact: true)

      assert html =~ "Not yet rated"
      assert html =~ "25 reviews"
      assert html =~ "hero-star"
      refute html =~ "hero-star-solid"
    end

    test "renders full rating display with breakdown" do
      stats = %RatingStats{
        average_rating: 7.8,
        total_reviews: 200,
        rating_distribution: %{"8" => 80, "7" => 60, "9" => 40, "6" => 20},
        source: "tmdb"
      }

      html = render_component(&rating_display/1, stats: stats, compact: false)

      assert html =~ "User Reviews"
      assert html =~ "7.8"
      assert html =~ "Based on 200 reviews"
      assert html =~ "Rating Breakdown"
      assert html =~ "40.0%" # 80/200 * 100 for rating "8"
      assert html =~ "30.0%" # 60/200 * 100 for rating "7"
    end

    test "renders full rating display without rating" do
      stats = %RatingStats{
        average_rating: nil,
        total_reviews: 50,
        rating_distribution: %{},
        source: "tmdb"
      }

      html = render_component(&rating_display/1, stats: stats, compact: false)

      assert html =~ "Not yet rated"
      assert html =~ "50 reviews without ratings"
      refute html =~ "Rating Breakdown"
    end

    test "renders full rating display with no reviews" do
      stats = %RatingStats{
        average_rating: nil,
        total_reviews: 0,
        rating_distribution: %{},
        source: "tmdb"
      }

      html = render_component(&rating_display/1, stats: stats, compact: false)

      assert html =~ "Not yet rated"
      assert html =~ "No reviews available"
    end

    test "hides source badge for merged stats" do
      stats = %RatingStats{
        average_rating: 8.0,
        total_reviews: 100,
        rating_distribution: %{},
        source: "merged"
      }

      html = render_component(&rating_display/1, stats: stats, compact: true)

      refute html =~ "merged"
      refute html =~ "uppercase tracking-wide"
    end
  end

  describe "compact_rating_display/1" do
    test "renders with rating and reviews count" do
      stats = %RatingStats{
        average_rating: 9.1,
        total_reviews: 75,
        source: "imdb"
      }

      html = render_component(&compact_rating_display/1, stats: stats, formatted_rating: "9.1")

      assert html =~ "9.1"
      assert html =~ "/10"
      assert html =~ "75 reviews"
      assert html =~ "imdb"
    end

    test "handles singular review count" do
      stats = %RatingStats{
        average_rating: 8.0,
        total_reviews: 1,
        source: "tmdb"
      }

      html = render_component(&compact_rating_display/1, stats: stats, formatted_rating: "8.0")

      assert html =~ "1 review"
      refute html =~ "1 reviews"
    end
  end

  describe "full_rating_display/1" do
    test "renders complete rating breakdown" do
      stats = %RatingStats{
        average_rating: 8.5,
        total_reviews: 300,
        rating_distribution: %{"10" => 50, "9" => 100, "8" => 80, "7" => 70},
        source: "tmdb"
      }

      rating_percentages = %{"10" => 16.7, "9" => 33.3, "8" => 26.7, "7" => 23.3}

      html = render_component(&full_rating_display/1,
        stats: stats,
        formatted_rating: "8.5",
        rating_percentages: rating_percentages
      )

      assert html =~ "User Reviews"
      assert html =~ "8.5"
      assert html =~ "Based on 300 reviews"
      assert html =~ "Rating Breakdown"
      assert html =~ "33.3%" # for rating 9
      assert html =~ "26.7%" # for rating 8
    end
  end

  describe "rating_bar/1" do
    test "renders rating bar with correct percentage" do
      html = render_component(&rating_bar/1, rating: "8", percentage: 45.5)

      assert html =~ "8"
      assert html =~ "width: 45.5%"
      assert html =~ "45.5%"
      assert html =~ "hero-star-solid"
    end

    test "renders rating bar with zero percentage" do
      html = render_component(&rating_bar/1, rating: "3", percentage: 0.0)

      assert html =~ "3"
      assert html =~ "width: 0.0%"
      assert html =~ "0.0%"
    end
  end

  describe "helper functions" do
    test "truncate_content/2 truncates long content" do
      long_content = "This is a very long piece of content that should be truncated."
      result = FlixirWeb.ReviewComponents.truncate_content(long_content, 20)

      assert String.length(result) <= 23 # 20 + "..."
      assert String.ends_with?(result, "...")
    end

    test "truncate_content/2 keeps short content unchanged" do
      short_content = "Short content"
      result = FlixirWeb.ReviewComponents.truncate_content(short_content, 50)

      assert result == short_content
    end

    test "has_spoilers?/1 detects spoiler keywords" do
      spoiler_content = "The ending was surprising when the main character dies."
      normal_content = "Great movie with excellent acting."

      assert FlixirWeb.ReviewComponents.has_spoilers?(spoiler_content)
      refute FlixirWeb.ReviewComponents.has_spoilers?(normal_content)
    end

    test "format_review_date/1 formats dates correctly" do
      today = DateTime.utc_now()
      yesterday = DateTime.add(today, -1, :day)
      week_ago = DateTime.add(today, -7, :day)
      month_ago = DateTime.add(today, -30, :day)

      assert FlixirWeb.ReviewComponents.format_review_date(today) == "Today"
      assert FlixirWeb.ReviewComponents.format_review_date(yesterday) == "Yesterday"
      assert FlixirWeb.ReviewComponents.format_review_date(week_ago) == "1 weeks ago"
      assert FlixirWeb.ReviewComponents.format_review_date(month_ago) == "1 months ago"
    end

    test "rating_percentages/1 calculates percentages correctly" do
      stats = %{total_reviews: 100, rating_distribution: %{"8" => 40, "7" => 35, "9" => 25}}
      result = FlixirWeb.ReviewComponents.rating_percentages(stats)

      assert result["8"] == 40.0
      assert result["7"] == 35.0
      assert result["9"] == 25.0
    end

    test "rating_percentages/1 handles zero reviews" do
      stats = %{total_reviews: 0, rating_distribution: %{}}
      result = FlixirWeb.ReviewComponents.rating_percentages(stats)

      assert result == %{}
    end

    test "format_average_rating/1 formats ratings correctly" do
      assert FlixirWeb.ReviewComponents.format_average_rating(8.567) == "8.6"
      assert FlixirWeb.ReviewComponents.format_average_rating(nil) == "N/A"
      assert FlixirWeb.ReviewComponents.format_average_rating(10.0) == "10.0"
    end
  end

  describe "edge cases and error handling" do
    test "handles review with empty content" do
      review = %Review{
        id: "empty",
        author: "Test User",
        content: "",
        rating: 5.0
      }

      html = render_component(&review_card/1, review: review)

      assert html =~ "Test User"
      assert html =~ "5.0"
    end

    test "handles review with very long author name" do
      review = %Review{
        id: "long-author",
        author: "This is a very long author name that might cause layout issues",
        content: "Good movie.",
        rating: 7.0
      }

      html = render_component(&review_card/1, review: review)

      assert html =~ "This is a very long author name"
      assert html =~ "T" # First letter in avatar
    end

    test "handles stats with negative percentages gracefully" do
      # This shouldn't happen in real data, but testing robustness
      html = render_component(&rating_bar/1, rating: "5", percentage: -5.0)

      assert html =~ "5"
      assert html =~ "width: -5.0%"
    end

    test "handles malformed rating distribution" do
      stats = %RatingStats{
        average_rating: 8.0,
        total_reviews: 100,
        rating_distribution: %{"invalid" => 50, "8" => 50},
        source: "test"
      }

      html = render_component(&rating_display/1, stats: stats, compact: false)

      assert html =~ "8.0"
      assert html =~ "100 reviews"
    end
  end
end
