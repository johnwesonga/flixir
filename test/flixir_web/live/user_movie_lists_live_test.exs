defmodule FlixirWeb.UserMovieListsLiveTest do
  use FlixirWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Mock

  alias Flixir.{Auth, Lists}
  alias Flixir.Lists.UserMovieList

  @valid_session_attrs %{
    tmdb_session_id: "test_session_123",
    tmdb_user_id: 12345,
    username: "testuser",
    expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
  }

  @valid_user_data %{
    "id" => 12345,
    "username" => "testuser",
    "name" => "Test User",
    "avatar" => %{"tmdb" => %{"avatar_path" => "/avatar.jpg"}}
  }

  setup %{conn: conn} do
    # Create a valid session for testing
    {:ok, session} = Auth.create_session(@valid_session_attrs)

    # Set up authenticated connection
    conn =
      conn
      |> init_test_session(%{})
      |> put_session("tmdb_session_id", session.tmdb_session_id)

    {:ok, conn: conn, session: session}
  end

  describe "mount/3" do
    test "redirects to login when not authenticated", %{conn: conn} do
      # Clear session to simulate unauthenticated user
      conn = clear_session(conn)

      assert {:error, {:redirect, %{to: "/auth/login"}}} = live(conn, ~p"/my-lists")
    end

    test "loads user lists when authenticated", %{conn: conn, session: session} do
      # Mock the Auth functions
      with_mocks([
        {Auth, [:passthrough],
         [
           validate_session: fn _session_id -> {:ok, session} end,
           get_current_user: fn _session_id -> {:ok, @valid_user_data} end
         ]},
        {Lists, [:passthrough],
         [
           get_user_lists: fn _user_id -> [] end,
           get_user_lists_summary: fn _user_id -> %{total_lists: 0, total_movies: 0} end
         ]}
      ]) do
        {:ok, view, html} = live(conn, ~p"/my-lists")

        assert html =~ "My Movie Lists"
        assert html =~ "No movie lists yet"
        assert has_element?(view, "[data-testid='empty-lists-state']")
      end
    end

    test "displays existing lists when user has lists", %{conn: conn, session: session} do
      # Create mock lists
      mock_lists = [
        %UserMovieList{
          id: "list-1",
          name: "My Watchlist",
          description: "Movies to watch",
          is_public: false,
          tmdb_user_id: 12345,
          list_items: [],
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        },
        %UserMovieList{
          id: "list-2",
          name: "Favorites",
          description: "My favorite movies",
          is_public: true,
          tmdb_user_id: 12345,
          # Mock 2 items
          list_items: [%{}, %{}],
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      ]

      with_mocks([
        {Auth, [:passthrough],
         [
           validate_session: fn _session_id -> {:ok, session} end,
           get_current_user: fn _session_id -> {:ok, @valid_user_data} end
         ]},
        {Lists, [:passthrough],
         [
           get_user_lists: fn _user_id -> mock_lists end,
           get_user_lists_summary: fn _user_id -> %{total_lists: 2, total_movies: 2} end
         ]}
      ]) do
        {:ok, view, html} = live(conn, ~p"/my-lists")

        assert html =~ "My Movie Lists"
        assert html =~ "My Watchlist"
        assert html =~ "Favorites"
        assert html =~ "Movies to watch"
        assert html =~ "My favorite movies"
        assert has_element?(view, "[data-testid='lists-grid']")
        refute has_element?(view, "[data-testid='empty-lists-state']")
      end
    end
  end

  describe "create list functionality" do
    test "shows create form when create button clicked", %{conn: conn, session: session} do
      with_mocks([
        {Auth, [:passthrough],
         [
           validate_session: fn _session_id -> {:ok, session} end,
           get_current_user: fn _session_id -> {:ok, @valid_user_data} end
         ]},
        {Lists, [:passthrough],
         [
           get_user_lists: fn _user_id -> [] end,
           get_user_lists_summary: fn _user_id -> %{total_lists: 0, total_movies: 0} end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/my-lists")

        # Click create button
        view |> element("[data-testid='create-first-list-button']") |> render_click()

        assert has_element?(view, "[data-testid='form-modal']")
        assert has_element?(view, "[data-testid='list-form']")
      end
    end

    test "creates new list successfully", %{conn: conn, session: session} do
      new_list = %UserMovieList{
        id: "new-list-id",
        name: "Test List",
        description: "Test description",
        is_public: false,
        tmdb_user_id: 12345,
        list_items: [],
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      # Track calls to get_user_lists to return the new list after creation
      {:ok, lists_agent} = Agent.start_link(fn -> [] end)

      get_user_lists_fn = fn _user_id ->
        Agent.get(lists_agent, & &1)
      end

      create_list_fn = fn _user_id, _attrs ->
        Agent.update(lists_agent, fn _ -> [new_list] end)
        {:ok, new_list}
      end

      with_mocks([
        {Auth, [:passthrough],
         [
           validate_session: fn _session_id -> {:ok, session} end,
           get_current_user: fn _session_id -> {:ok, @valid_user_data} end
         ]},
        {Lists, [:passthrough],
         [
           get_user_lists: get_user_lists_fn,
           get_user_lists_summary: fn _user_id -> %{total_lists: 0, total_movies: 0} end,
           create_list: create_list_fn
         ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/my-lists")

        # Show create form
        view |> element("[data-testid='create-first-list-button']") |> render_click()

        # Fill and submit form
        view
        |> form("[data-testid='list-form'] form",
          user_movie_list: %{
            name: "Test List",
            description: "Test description",
            is_public: false
          }
        )
        |> render_submit()

        # Should show the new list in the grid
        assert render(view) =~ "Test List"
        assert render(view) =~ "Test description"
        assert has_element?(view, "[data-testid='lists-grid']")
      end

      Agent.stop(lists_agent)
    end
  end

  describe "error handling" do
    test "shows error state when loading fails", %{conn: conn, session: session} do
      with_mocks([
        {Auth, [:passthrough],
         [
           validate_session: fn _session_id -> {:ok, session} end,
           get_current_user: fn _session_id -> {:ok, @valid_user_data} end
         ]},
        {Lists, [:passthrough],
         [
           get_user_lists: fn _user_id -> raise "Database error" end,
           get_user_lists_summary: fn _user_id -> %{total_lists: 0, total_movies: 0} end
         ]}
      ]) do
        {:ok, view, html} = live(conn, ~p"/my-lists")

        assert html =~ "Failed to load your movie lists"
        assert has_element?(view, "[data-testid='error-state']")
      end
    end

    test "retry button reloads lists", %{conn: conn, session: session} do
      with_mocks([
        {Auth, [:passthrough],
         [
           validate_session: fn _session_id -> {:ok, session} end,
           get_current_user: fn _session_id -> {:ok, @valid_user_data} end
         ]},
        {Lists, [:passthrough],
         [
           get_user_lists: fn _user_id -> raise "Database error" end,
           get_user_lists_summary: fn _user_id -> %{total_lists: 0, total_movies: 0} end
         ]}
      ]) do
        {:ok, view, _html} = live(conn, ~p"/my-lists")

        # Should show error state
        assert has_element?(view, "[data-testid='error-state']")

        # Verify retry button exists
        assert has_element?(view, "button", "Try Again")
      end
    end
  end
end
