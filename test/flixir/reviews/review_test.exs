defmodule Flixir.Reviews.ReviewTest do
  use ExUnit.Case, async: true

  alias Flixir.Reviews.Review

  describe "new/1" do
    test "creates a review with valid attributes" do
      attrs = %{
        id: "123",
        author: "John Doe",
        content: "Great movie!",
        rating: 8.5
      }

      assert {:ok, review} = Review.new(attrs)
      assert review.id == "123"
      assert review.author == "John Doe"
      assert review.content == "Great movie!"
      assert review.rating == 8.5
      assert review.author_details == %{}
    end

    test "creates a review with string keys" do
      attrs = %{
        "id" => "456",
        "author" => "Jane Smith",
        "content" => "Excellent show!",
        "rating" => "7.5"
      }

      assert {:ok, review} = Review.new(attrs)
      assert review.id == "456"
      assert review.author == "Jane Smith"
      assert review.content == "Excellent show!"
      assert review.rating == 7.5
    end

    test "parses datetime strings correctly" do
      attrs = %{
        id: "123",
        author: "John",
        content: "Good",
        created_at: "2023-01-01T12:00:00Z"
      }

      assert {:ok, review} = Review.new(attrs)
      assert %DateTime{} = review.created_at
      assert review.created_at.year == 2023
    end

    test "handles invalid datetime strings" do
      attrs = %{
        id: "123",
        author: "John",
        content: "Good",
        created_at: "invalid-date"
      }

      assert {:ok, review} = Review.new(attrs)
      assert is_nil(review.created_at)
    end

    test "validates rating range" do
      valid_attrs = %{id: "123", author: "John", content: "Good"}

      # Valid ratings
      assert {:ok, review} = Review.new(Map.put(valid_attrs, :rating, 5.0))
      assert review.rating == 5.0

      assert {:ok, review} = Review.new(Map.put(valid_attrs, :rating, 0))
      assert review.rating == 0

      assert {:ok, review} = Review.new(Map.put(valid_attrs, :rating, 10))
      assert review.rating == 10

      # Invalid ratings
      assert {:ok, review} = Review.new(Map.put(valid_attrs, :rating, -1))
      assert is_nil(review.rating)

      assert {:ok, review} = Review.new(Map.put(valid_attrs, :rating, 11))
      assert is_nil(review.rating)
    end

    test "returns error for missing required fields" do
      # Missing id
      assert {:error, {:missing_required_fields, fields}} =
               Review.new(%{author: "John", content: "Good"})

      assert :id in fields

      # Missing author
      assert {:error, {:missing_required_fields, fields}} =
               Review.new(%{id: "123", content: "Good"})

      assert :author in fields

      # Missing content
      assert {:error, {:missing_required_fields, fields}} =
               Review.new(%{id: "123", author: "John"})

      assert :content in fields

      # Empty strings count as missing
      assert {:error, {:missing_required_fields, _}} =
               Review.new(%{id: "", author: "John", content: "Good"})

      assert {:error, {:missing_required_fields, _}} =
               Review.new(%{id: "123", author: "  ", content: "Good"})
    end
  end

  describe "valid?/1" do
    test "returns true for valid review" do
      review = %Review{
        id: "123",
        author: "John Doe",
        content: "Great movie!"
      }

      assert Review.valid?(review)
    end

    test "returns false for invalid review" do
      # Missing id
      review = %Review{id: nil, author: "John", content: "Good"}
      refute Review.valid?(review)

      # Missing author
      review = %Review{id: "123", author: nil, content: "Good"}
      refute Review.valid?(review)

      # Missing content
      review = %Review{id: "123", author: "John", content: nil}
      refute Review.valid?(review)

      # Empty strings
      review = %Review{id: "123", author: "", content: "Good"}
      refute Review.valid?(review)

      review = %Review{id: "123", author: "John", content: "  "}
      refute Review.valid?(review)
    end
  end

  describe "truncate_content/2" do
    test "truncates long content" do
      review = %Review{content: "This is a very long review content that should be truncated"}

      result = Review.truncate_content(review, 20)
      assert result == "This is a very long ..."
      # 20 + "..."
      assert String.length(result) == 23
    end

    test "returns full content if shorter than limit" do
      review = %Review{content: "Short review"}

      result = Review.truncate_content(review, 20)
      assert result == "Short review"
    end

    test "returns full content if exactly at limit" do
      review = %Review{content: "Exactly twenty chars"}

      result = Review.truncate_content(review, 20)
      assert result == "Exactly twenty chars"
    end
  end
end
