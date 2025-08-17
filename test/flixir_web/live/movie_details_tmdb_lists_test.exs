defmodule FlixirWeb.MovieDetailsTMDBListsTest do
  @moduledoc """
  Tests for TMDB list integration in MovieDetailsLive.
  """

  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.{Lists, Media, Reviews}

  # Common mock functions
  defp mock_reviews_functions(media_type, media_id) do
    [
      get_reviews: fn(^media_type, ^media_id, _opts) -> {:ok, %{reviews: [], pagination: %{has_next: false}}} end,
      get_rating_stats: fn(^media_type, ^media_id) -> {:ok, %{
        total_reviews: 0,
        average_rating: 0.0,
        source: "tmdb",
        rating_distribution: %{}
      }} end,
      filter_reviews: fn(reviews, _filters) -> reviews end,
      sort_reviews: fn(reviews, _sort_by, _sort_order) -> reviews end,
      paginate_reviews: fn(reviews, _page, _per_page) -> %{reviews: reviews, pagination: %{has_next: false}} end
    ]
  end

  describe "TMDB list integration" do
    setup do
      # Mock user session data
      current_user = %{
        tmdb_user_id: 12345,
        username: "testuser",
        session_id: "test_session_123"
      }

      # Mock movie data
      movie_data = %{
        "id" => 550,
        "title" => "Fight Club",
        "overview" => "A movie about fighting.",
        "poster_path" => "/poster.jpg",
        "release_date" => "1999-10-15",
        "vote_average" => 8.8
      }

      # Mock user lists
      user_lists = [
        %{
          "id" => 789,
          "name" => "My Watchlist",
          "description" => "Movies to watch",
          "public" => false,
          "item_count" => 5,
          "created_at" => "2024-01-01T12:00:00Z",
          "updated_at" => "2024-01-02T15:30:00Z"
        },
        %{
          "id" => 790,
          "name" => "Favorites",
          "description" => "My favorite movies",
          "public" => true,
          "item_count" => 10,
          "created_at" => "2024-01-01T12:00:00Z",
          "updated_at" => "2024-01-03T10:00:00Z"
        }
      ]

      %{
        current_user: current_user,
        movie_data: movie_data,
        user_lists: user_lists
      }
    end

    test "loads user lists for authenticated users", %{
      conn: conn,
      current_user: current_user,
      movie_data: movie_data,
      user_lists: user_lists
    } do
      with_mocks([
        {Media, [], [get_content_details: fn(550, :movie) -> {:ok, movie_data} end]},
        {Reviews, [], mock_reviews_functions("movie", 550)},
        {Lists, [], [get_user_lists: fn(12345) -> {:ok, user_lists} end]},
        {Lists, [], [movie_in_list?: fn(_list_id, _movie_id, _user_id) -> {:ok, false} end]}
      ]) do
        # Set up authenticated session
        conn =
          conn
          |> init_test_session(%{})
          |> put_session(:current_user, current_user)
          |> put_session(:authenticated?, true)

        {:ok, view, html} = live(conn, "/media/movie/550")

        # Check that the TMDB list integration section is present
        assert html =~ "My Lists"
        assert html =~ "Add to List"

        # Check that user lists are displayed
        assert html =~ "My Watchlist"
        assert html =~ "Favorites"

        # Verify the lists were loaded
        assert view.assigns.user_lists == user_lists
        assert view.assigns.tmdb_user_id == 12345
      end
    end

    test "shows add to list modal when button is clicked", %{
      conn: conn,
      current_user: current_user,
      movie_data: movie_data,
      user_lists: user_lists
    } do
      with_mocks([
        {Media, [], [get_content_details: fn(550, :movie) -> {:ok, movie_data} end]},
        {Reviews, [], mock_reviews_functions("movie", 550)},
        {Lists, [], [get_user_lists: fn(12345) -> {:ok, user_lists} end]},
        {Lists, [], [movie_in_list?: fn(_list_id, _movie_id, _user_id) -> {:ok, false} end]}
      ]) do
        # Set up authenticated session
        conn =
          conn
          |> init_test_session(%{})
          |> put_session(:current_user, current_user)
          |> put_session(:authenticated?, true)

        {:ok, view, _html} = live(conn, "/media/movie/550")

        # Initially modal should not be shown
        refute view.assigns.show_add_to_list

        # Click the "Add to List" button
        view |> element("button", "Add to List") |> render_click()

        # Modal should now be shown
        assert view.assigns.show_add_to_list

        # Check that modal content is rendered
        html = render(view)
        assert html =~ "Add to List"
        assert html =~ "My Watchlist"
        assert html =~ "Favorites"
      end
    end

    test "adds movie to list with optimistic updates", %{
      conn: conn,
      current_user: current_user,
      movie_data: movie_data,
      user_lists: user_lists
    } do
      with_mocks([
        {Media, [], [get_content_details: fn(550, :movie) -> {:ok, movie_data} end]},
        {Reviews, [], mock_reviews_functions("movie", 550)},
        {Lists, [], [get_user_lists: fn(12345) -> {:ok, user_lists} end]},
        {Lists, [], [movie_in_list?: fn(_list_id, _movie_id, _user_id) -> {:ok, false} end]},
        {Lists, [], [add_movie_to_list: fn(789, 550, 12345) -> {:ok, :added} end]}
      ]) do
        # Set up authenticated session
        conn =
          conn
          |> init_test_session(%{})
          |> put_session(:current_user, current_user)
          |> put_session(:authenticated?, true)

        {:ok, view, _html} = live(conn, "/media/movie/550")

        # Show the modal
        view |> element("button", "Add to List") |> render_click()

        # Add movie to the first list
        view
        |> element("button[phx-value-list-id='789'][phx-value-movie-id='550']")
        |> render_click()

        # Check that the movie was added (optimistic update should be reflected)
        assert view.assigns.movie_list_membership[789] == true

        # Modal should be closed
        refute view.assigns.show_add_to_list

        # Check for success flash message
        assert_receive {:flash, :info, "Movie added to list successfully!"}
      end
    end

    test "handles TMDB API errors gracefully", %{
      conn: conn,
      current_user: current_user,
      movie_data: movie_data,
      user_lists: user_lists
    } do
      with_mocks([
        {Media, [], [get_content_details: fn(550, :movie) -> {:ok, movie_data} end]},
        {Reviews, [], mock_reviews_functions("movie", 550)},
        {Lists, [], [get_user_lists: fn(12345) -> {:ok, user_lists} end]},
        {Lists, [], [movie_in_list?: fn(_list_id, _movie_id, _user_id) -> {:ok, false} end]},
        {Lists, [], [add_movie_to_list: fn(789, 550, 12345) -> {:error, :api_unavailable} end]}
      ]) do
        # Set up authenticated session
        conn =
          conn
          |> init_test_session(%{})
          |> put_session(:current_user, current_user)
          |> put_session(:authenticated?, true)

        {:ok, view, _html} = live(conn, "/media/movie/550")

        # Show the modal and try to add movie
        view |> element("button", "Add to List") |> render_click()

        view
        |> element("button[phx-value-list-id='789'][phx-value-movie-id='550']")
        |> render_click()

        # Check for error flash message
        assert_receive {:flash, :error, "TMDB service is temporarily unavailable"}
      end
    end

    test "does not show TMDB list integration for unauthenticated users", %{
      conn: conn,
      movie_data: movie_data
    } do
      with_mocks([
        {Media, [], [get_content_details: fn(550, :movie) -> {:ok, movie_data} end]},
        {Reviews, [], mock_reviews_functions("movie", 550)}
      ]) do
        {:ok, _view, html} = live(conn, "/media/movie/550")

        # TMDB list integration should not be present for unauthenticated users
        refute html =~ "My Lists"
        refute html =~ "Add to List"
      end
    end

    test "only shows TMDB list integration for movies, not TV shows", %{
      conn: conn,
      current_user: current_user
    } do
      tv_show_data = %{
        "id" => 1399,
        "name" => "Game of Thrones",
        "overview" => "A TV show about thrones.",
        "poster_path" => "/poster.jpg",
        "first_air_date" => "2011-04-17",
        "vote_average" => 9.2
      }

      with_mocks([
        {Media, [], [get_content_details: fn(1399, :tv) -> {:ok, tv_show_data} end]},
        {Reviews, [], mock_reviews_functions("tv", 1399)}
      ]) do
        # Set up authenticated session
        conn =
          conn
          |> init_test_session(%{})
          |> put_session(:current_user, current_user)
          |> put_session(:authenticated?, true)

        {:ok, _view, html} = live(conn, "/media/tv/1399")

        # TMDB list integration should not be present for TV shows
        refute html =~ "My Lists"
        refute html =~ "Add to List"
      end
    end
  end
end
