defmodule FlixirWeb.RouterTest do
  use FlixirWeb.ConnCase, async: true

  describe "TMDB list routing" do
    test "routes to user movie lists with TMDB list IDs", %{conn: _conn} do
      # Test that the router accepts integer TMDB list IDs
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/my-lists/123", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123"}
      assert route_info.plug == Phoenix.LiveView.Plug

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/my-lists/456/edit", "")
      assert route_info.path_params == %{"tmdb_list_id" => "456"}
      assert route_info.plug == Phoenix.LiveView.Plug
    end

    test "routes to public TMDB lists", %{conn: _conn} do
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/lists/public/789", "")
      assert route_info.path_params == %{"tmdb_list_id" => "789"}
      assert route_info.plug == Phoenix.LiveView.Plug
    end

    test "routes to shared TMDB lists", %{conn: _conn} do
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/lists/shared/101112", "")
      assert route_info.path_params == %{"tmdb_list_id" => "101112"}
      assert route_info.plug == Phoenix.LiveView.Plug
    end

    test "routes to external TMDB list redirects", %{conn: _conn} do
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/lists/external/131415", "")
      assert route_info.path_params == %{"tmdb_list_id" => "131415"}
      assert route_info.plug == FlixirWeb.ListController
    end

    test "API routes for TMDB lists", %{conn: _conn} do
      # Test CRUD API routes
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/api/lists", "")
      assert route_info.plug == FlixirWeb.Api.ListController
      assert route_info.plug_opts == :index

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "POST", "/api/lists", "")
      assert route_info.plug == FlixirWeb.Api.ListController
      assert route_info.plug_opts == :create

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/api/lists/123", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123"}
      assert route_info.plug == FlixirWeb.Api.ListController
      assert route_info.plug_opts == :show

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "PUT", "/api/lists/123", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123"}
      assert route_info.plug == FlixirWeb.Api.ListController
      assert route_info.plug_opts == :update

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "DELETE", "/api/lists/123", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123"}
      assert route_info.plug == FlixirWeb.Api.ListController
      assert route_info.plug_opts == :delete
    end

    test "API routes for TMDB list movie operations", %{conn: _conn} do
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "POST", "/api/lists/123/movies", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123"}
      assert route_info.plug == FlixirWeb.Api.ListController
      assert route_info.plug_opts == :add_movie

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "DELETE", "/api/lists/123/movies/456", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123", "tmdb_movie_id" => "456"}
      assert route_info.plug == FlixirWeb.Api.ListController
      assert route_info.plug_opts == :remove_movie
    end

    test "API routes for sync operations", %{conn: _conn} do
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "POST", "/api/lists/sync", "")
      assert route_info.plug == FlixirWeb.Api.SyncController
      assert route_info.plug_opts == :sync_all_lists

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "POST", "/api/lists/123/sync", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123"}
      assert route_info.plug == FlixirWeb.Api.SyncController
      assert route_info.plug_opts == :sync_list

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/api/lists/sync/status", "")
      assert route_info.plug == FlixirWeb.Api.SyncController
      assert route_info.plug_opts == :sync_status
    end

    test "API routes for queue management", %{conn: _conn} do
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/api/lists/queue", "")
      assert route_info.plug == FlixirWeb.Api.QueueController
      assert route_info.plug_opts == :index

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "POST", "/api/lists/queue/retry", "")
      assert route_info.plug == FlixirWeb.Api.QueueController
      assert route_info.plug_opts == :retry_all

      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/api/lists/queue/stats", "")
      assert route_info.plug == FlixirWeb.Api.QueueController
      assert route_info.plug_opts == :stats
    end
  end

  describe "parameter validation" do
    test "TMDB list ID parameter validation in LiveView mount" do
      # This would be tested in the LiveView tests, but we can verify
      # that the router accepts the parameters correctly

      # Valid integer IDs should work
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/my-lists/123", "")
      assert route_info.path_params == %{"tmdb_list_id" => "123"}

      # String IDs should also be accepted (validation happens in mount)
      route_info = Phoenix.Router.route_info(FlixirWeb.Router, "GET", "/my-lists/abc", "")
      assert route_info.path_params == %{"tmdb_list_id" => "abc"}
    end
  end
end
