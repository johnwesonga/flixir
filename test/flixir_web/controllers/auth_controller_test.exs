defmodule FlixirWeb.AuthControllerTest do
  use FlixirWeb.ConnCase

  describe "store_session/2" do
    test "stores session ID and redirects to default path", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get(~p"/auth/store_session?session_id=test_session_123")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "tmdb_session_id") == "test_session_123"
    end

    test "stores session ID and redirects to specified path", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get(~p"/auth/store_session?session_id=test_session_123&redirect_to=/movies")

      assert redirected_to(conn) == "/movies"
      assert get_session(conn, "tmdb_session_id") == "test_session_123"
    end

    test "handles URL encoded redirect paths", %{conn: conn} do
      encoded_path = URI.encode("/movies/popular")
      conn =
        conn
        |> init_test_session(%{})
        |> get("/auth/store_session?session_id=test_session_123&redirect_to=#{encoded_path}")

      assert redirected_to(conn) == "/movies/popular"
      assert get_session(conn, "tmdb_session_id") == "test_session_123"
    end

    test "clears redirect_after_login session", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{redirect_after_login: "/movies"})
        |> get(~p"/auth/store_session?session_id=test_session_123")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "tmdb_session_id") == "test_session_123"
      assert get_session(conn, :redirect_after_login) == nil
    end
  end

  describe "clear_session/2" do
    test "clears session and redirects to home", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{"tmdb_session_id" => "test_session_123"})
        |> get(~p"/auth/clear_session")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "tmdb_session_id") == nil
    end

    test "works even when no session exists", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get(~p"/auth/clear_session")

      assert redirected_to(conn) == "/"
      assert get_session(conn, "tmdb_session_id") == nil
    end
  end
end
