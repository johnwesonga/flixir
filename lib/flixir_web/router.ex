defmodule FlixirWeb.Router do
  use FlixirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FlixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FlixirWeb do
    pipe_through :browser

    # Home/Search
    live "/", SearchLive, :home
    live "/search", SearchLive, :index

    # Movies section
    live "/movies", MovieListsLive, :index
    live "/movies/:list_type", MovieListsLive, :show

    # Reviews section
    live "/reviews", ReviewsLive, :index
    live "/reviews/:filter", ReviewsLive, :show

    # Media details (movies/TV shows with reviews)
    live "/:type/:id", MovieDetailsLive, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", FlixirWeb do
  #   pipe_through :api
  # end

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
end
