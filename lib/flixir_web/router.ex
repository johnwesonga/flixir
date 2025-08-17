defmodule FlixirWeb.Router do
  use FlixirWeb, :router

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:flixir, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FlixirWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FlixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug FlixirWeb.Plugs.AuthSession
  end

  pipeline :authenticated do
    plug :browser
    plug FlixirWeb.Plugs.AuthSession, require_auth: true
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug FlixirWeb.Plugs.AuthSession
  end

  pipeline :require_auth do
    plug FlixirWeb.Plugs.AuthSession, require_auth: true
  end

  # LiveView socket configuration

  scope "/", FlixirWeb do
    pipe_through :browser

    # Home/Search
    live "/", SearchLive, :home
    live "/search", SearchLive, :index

    # Authentication routes
    live "/auth/login", AuthLive, :login
    live "/auth/callback", AuthLive, :callback
    live "/auth/logout", AuthLive, :logout

    # Authentication session management
    get "/auth/store_session", AuthController, :store_session
    get "/auth/clear_session", AuthController, :clear_session

    # Movies section
    live "/movies", MovieListsLive, :index
    live "/movies/:list_type", MovieListsLive, :show

    # Reviews section
    live "/reviews", ReviewsLive, :index
    live "/reviews/:filter", ReviewsLive, :show

    # Media details (movies/TV shows with reviews) - moved to end to avoid conflicts
    live "/media/:type/:id", MovieDetailsLive, :show
  end

  # Protected routes that require authentication
  scope "/", FlixirWeb do
    pipe_through :authenticated

    # User movie lists management - using TMDB list IDs (integers)
    live "/my-lists", UserMovieListsLive, :index
    live "/my-lists/new", UserMovieListsLive, :new
    live "/my-lists/:tmdb_list_id", UserMovieListLive, :show
  end

  # Public TMDB list sharing routes (no authentication required)
  scope "/lists", FlixirWeb do
    pipe_through :browser

    # Public TMDB list access and sharing
    live "/public/:tmdb_list_id", PublicListLive, :show
    live "/shared/:tmdb_list_id", SharedListLive, :show

    # External TMDB list links (redirects to TMDB)
    get "/external/:tmdb_list_id", ListController, :external_redirect, constraints: %{tmdb_list_id: ~r/\d+/}
  end

  # API routes for TMDB list operations
  scope "/api", FlixirWeb do
    pipe_through :api

    # Public API routes (no authentication required for read-only operations)
    get "/lists/public/:tmdb_list_id", Api.ListController, :show_public, constraints: %{tmdb_list_id: ~r/\d+/}
    get "/lists/shared/:tmdb_list_id", Api.ListController, :show_shared, constraints: %{tmdb_list_id: ~r/\d+/}
  end

  # Protected API routes that require authentication
  scope "/api", FlixirWeb do
    pipe_through [:api, :require_auth]

    # Sync operations (must come before parameterized routes)
    post "/lists/sync", Api.SyncController, :sync_all_lists
    get "/lists/sync/status", Api.SyncController, :sync_status
    post "/lists/:tmdb_list_id/sync", Api.SyncController, :sync_list, constraints: %{tmdb_list_id: ~r/\d+/}

    # Queue management operations (must come before parameterized routes)
    get "/lists/queue", Api.QueueController, :index
    post "/lists/queue/retry", Api.QueueController, :retry_all
    get "/lists/queue/stats", Api.QueueController, :stats
    post "/lists/queue/:operation_id/retry", Api.QueueController, :retry_operation
    delete "/lists/queue/:operation_id", Api.QueueController, :cancel_operation

    # TMDB list CRUD operations
    post "/lists", Api.ListController, :create
    get "/lists", Api.ListController, :index
    get "/lists/:tmdb_list_id", Api.ListController, :show, constraints: %{tmdb_list_id: ~r/\d+/}

    delete "/lists/:tmdb_list_id", Api.ListController, :delete, constraints: %{tmdb_list_id: ~r/\d+/}
    post "/lists/:tmdb_list_id/clear", Api.ListController, :clear, constraints: %{tmdb_list_id: ~r/\d+/}

    # TMDB list movie operations
    post "/lists/:tmdb_list_id/movies", Api.ListController, :add_movie, constraints: %{tmdb_list_id: ~r/\d+/}
    delete "/lists/:tmdb_list_id/movies/:tmdb_movie_id", Api.ListController, :remove_movie,
      constraints: %{tmdb_list_id: ~r/\d+/, tmdb_movie_id: ~r/\d+/}

    # TMDB list sharing operations
    post "/lists/:tmdb_list_id/share", Api.ListController, :share, constraints: %{tmdb_list_id: ~r/\d+/}
  end
end
