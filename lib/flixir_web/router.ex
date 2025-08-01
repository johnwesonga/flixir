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

    # Future authenticated-only features will go here
    # Examples: user watchlists, ratings, personal reviews, etc.
  end

  # Other scopes may use custom stacks.
  # scope "/api", FlixirWeb do
  #   pipe_through :api
  # end
end
