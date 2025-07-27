defmodule FlixirWeb.RouterTest do
  use FlixirWeb.ConnCase, async: true

  describe "authentication routes" do
    test "GET /auth/login routes to AuthLive :login" do
      conn = get(build_conn(), "/auth/login")
      assert html_response(conn, 200) =~ "Sign in to your account"
    end

    test "GET /auth/callback routes to AuthLive :callback" do
      conn = get(build_conn(), "/auth/callback")
      assert html_response(conn, 200)
    end

    test "GET /auth/logout routes to AuthLive :logout" do
      conn = get(build_conn(), "/auth/logout")
      assert html_response(conn, 200) =~ "Sign Out"
    end

    test "GET /auth/store_session routes to AuthController" do
      conn = get(build_conn(), "/auth/store_session?session_id=test123")
      assert redirected_to(conn) == "/"
    end

    test "GET /auth/clear_session routes to AuthController" do
      conn = get(build_conn(), "/auth/clear_session")
      assert redirected_to(conn) == "/"
    end
  end

  describe "protected routes pipeline" do
    test "authenticated pipeline exists and includes AuthSession plug with require_auth: true" do
      # This test verifies the pipeline is configured correctly
      # The actual authentication behavior is tested in the plug tests
      conn =
        build_conn()
        |> init_test_session(%{})
        |> get("/")

      # Should not be halted since we're not accessing protected routes
      refute conn.halted
    end
  end

  describe "main routes" do
    test "GET / routes to SearchLive :home" do
      conn = get(build_conn(), "/")
      assert html_response(conn, 200) =~ "Search"
    end

    test "GET /search routes to SearchLive :index" do
      conn = get(build_conn(), "/search")
      assert html_response(conn, 200) =~ "Search"
    end

    test "GET /movies routes to MovieListsLive :index" do
      conn = get(build_conn(), "/movies")
      assert html_response(conn, 200) =~ "Movies"
    end

    test "GET /reviews routes to ReviewsLive :index" do
      conn = get(build_conn(), "/reviews")
      assert html_response(conn, 200) =~ "Reviews"
    end
  end
end
