defmodule Flixir.ListsTest do
  use Flixir.DataCase

  alias Flixir.Lists
  alias Flixir.Lists.{UserMovieList, UserMovieListItem}

  describe "create_list/2" do
    test "creates a list with valid attributes" do
      attrs = %{
        name: "My Watchlist",
        description: "Movies I want to watch",
        is_public: false
      }

      assert {:ok, %UserMovieList{} = list} = Lists.create_list(12345, attrs)
      assert list.name == "My Watchlist"
      assert list.description == "Movies I want to watch"
      assert list.is_public == false
      assert list.tmdb_user_id == 12345
    end

    test "returns error with invalid attributes" do
      attrs = %{name: ""}

      assert {:error, %Ecto.Changeset{}} = Lists.create_list(12345, attrs)
    end
  end

  describe "get_user_lists/1" do
    test "returns all lists for a user ordered by updated_at desc" do
      user_id = 12345

      # Create multiple lists
      {:ok, _list1} = Lists.create_list(user_id, %{name: "List 1"})
      {:ok, _list2} = Lists.create_list(user_id, %{name: "List 2"})

      lists = Lists.get_user_lists(user_id)

      assert length(lists) == 2
      # Verify they are ordered by updated_at desc
      [first, second] = lists
      assert NaiveDateTime.compare(first.updated_at, second.updated_at) in [:gt, :eq]
    end

    test "returns empty list for user with no lists" do
      lists = Lists.get_user_lists(99999)
      assert lists == []
    end
  end

  describe "get_list/2" do
    test "returns list when user owns it" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      assert {:ok, retrieved_list} = Lists.get_list(list.id, user_id)
      assert retrieved_list.id == list.id
      assert retrieved_list.name == "Test List"
    end

    test "returns not_found for non-existent list" do
      assert {:error, :not_found} = Lists.get_list(Ecto.UUID.generate(), 12345)
    end

    test "returns unauthorized when user doesn't own list" do
      user_id = 12345
      other_user_id = 67890
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      assert {:error, :unauthorized} = Lists.get_list(list.id, other_user_id)
    end
  end

  describe "update_list/2" do
    test "updates list with valid attributes" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Original Name"})

      attrs = %{name: "Updated Name", description: "New description"}
      assert {:ok, updated_list} = Lists.update_list(list, attrs)
      assert updated_list.name == "Updated Name"
      assert updated_list.description == "New description"
    end

    test "returns error with invalid attributes" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      attrs = %{name: ""}
      assert {:error, %Ecto.Changeset{}} = Lists.update_list(list, attrs)
    end
  end

  describe "delete_list/1" do
    test "deletes the list" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      assert {:ok, deleted_list} = Lists.delete_list(list)
      assert deleted_list.id == list.id

      # Verify it's actually deleted
      assert {:error, :not_found} = Lists.get_list(list.id, user_id)
    end
  end

  describe "clear_list/1" do
    test "removes all movies from list but preserves list" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      # Add some movies (we'll mock this since we don't have the full movie management yet)
      Repo.insert!(%UserMovieListItem{
        list_id: list.id,
        tmdb_movie_id: 550,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      Repo.insert!(%UserMovieListItem{
        list_id: list.id,
        tmdb_movie_id: 551,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert {:ok, {2, nil}} = Lists.clear_list(list)

      # Verify list still exists but has no items
      {:ok, updated_list} = Lists.get_list(list.id, user_id)
      assert length(updated_list.list_items) == 0
    end
  end

  describe "add_movie_to_list/3" do
    test "adds movie to list successfully" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      assert {:ok, %UserMovieListItem{} = item} = Lists.add_movie_to_list(list.id, 550, user_id)
      assert item.tmdb_movie_id == 550
      assert item.list_id == list.id
    end

    test "returns error when trying to add duplicate movie" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      # Add movie first time
      assert {:ok, _item} = Lists.add_movie_to_list(list.id, 550, user_id)

      # Try to add same movie again
      assert {:error, :duplicate_movie} = Lists.add_movie_to_list(list.id, 550, user_id)
    end

    test "returns unauthorized when user doesn't own list" do
      user_id = 12345
      other_user_id = 67890
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      assert {:error, :unauthorized} = Lists.add_movie_to_list(list.id, 550, other_user_id)
    end
  end

  describe "remove_movie_from_list/3" do
    test "removes movie from list successfully" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      # Add movie first
      {:ok, _item} = Lists.add_movie_to_list(list.id, 550, user_id)

      # Remove movie
      assert {:ok, %UserMovieListItem{}} = Lists.remove_movie_from_list(list.id, 550, user_id)

      # Verify it's removed
      assert Lists.movie_in_list?(list.id, 550) == false
    end

    test "returns not_found when movie is not in list" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      assert {:error, :not_found} = Lists.remove_movie_from_list(list.id, 550, user_id)
    end

    test "returns unauthorized when user doesn't own list" do
      user_id = 12345
      other_user_id = 67890
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      # Add movie as owner
      {:ok, _item} = Lists.add_movie_to_list(list.id, 550, user_id)

      # Try to remove as different user
      assert {:error, :unauthorized} = Lists.remove_movie_from_list(list.id, 550, other_user_id)
    end
  end

  describe "movie_in_list?/2" do
    test "returns true when movie is in list" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      Repo.insert!(%UserMovieListItem{
        list_id: list.id,
        tmdb_movie_id: 550,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert Lists.movie_in_list?(list.id, 550) == true
    end

    test "returns false when movie is not in list" do
      user_id = 12345
      {:ok, list} = Lists.create_list(user_id, %{name: "Test List"})

      assert Lists.movie_in_list?(list.id, 550) == false
    end
  end

  describe "get_list_stats/1" do
    test "returns correct statistics for list" do
      user_id = 12345

      {:ok, list} =
        Lists.create_list(user_id, %{name: "Test List", description: "Test description"})

      # Add some movies
      Repo.insert!(%UserMovieListItem{
        list_id: list.id,
        tmdb_movie_id: 550,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      Repo.insert!(%UserMovieListItem{
        list_id: list.id,
        tmdb_movie_id: 551,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      stats = Lists.get_list_stats(list.id)

      assert stats.movie_count == 2
      assert stats.name == "Test List"
      assert stats.description == "Test description"
      assert stats.is_public == false
      assert stats.created_at == list.inserted_at
      assert stats.updated_at == list.updated_at
    end

    test "returns error for non-existent list" do
      stats = Lists.get_list_stats(Ecto.UUID.generate())
      assert stats.error == :not_found
    end
  end

  describe "get_user_lists_summary/1" do
    test "returns correct summary for user with lists" do
      user_id = 12345

      # Create lists
      {:ok, list1} = Lists.create_list(user_id, %{name: "List 1", is_public: true})
      {:ok, list2} = Lists.create_list(user_id, %{name: "List 2", is_public: false})

      # Add movies to lists
      Repo.insert!(%UserMovieListItem{
        list_id: list1.id,
        tmdb_movie_id: 550,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      Repo.insert!(%UserMovieListItem{
        list_id: list2.id,
        tmdb_movie_id: 551,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      Repo.insert!(%UserMovieListItem{
        list_id: list2.id,
        tmdb_movie_id: 552,
        added_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      summary = Lists.get_user_lists_summary(user_id)

      assert summary.total_lists == 2
      assert summary.total_movies == 3
      assert summary.public_lists == 1
      assert summary.private_lists == 1
      assert summary.most_recent_list.id in [list1.id, list2.id]
      assert summary.largest_list.movie_count == 2
      assert summary.largest_list.name == "List 2"
    end

    test "returns empty summary for user with no lists" do
      summary = Lists.get_user_lists_summary(99999)

      assert summary.total_lists == 0
      assert summary.total_movies == 0
      assert summary.public_lists == 0
      assert summary.private_lists == 0
      assert summary.most_recent_list == nil
      assert summary.largest_list == nil
    end
  end
end
