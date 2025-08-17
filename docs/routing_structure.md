# Routing Structure Documentation

This document outlines the comprehensive routing structure of Flixir, including web routes, API endpoints, and route organization.

## Route Organization

Flixir's routing is organized into logical groups based on functionality and authentication requirements:

### 1. Public Web Routes (`/`)

**Base Pipeline**: `:browser` (includes session management, CSRF protection, and authentication context)

```elixir
# Home and Search
live "/", SearchLive, :home
live "/search", SearchLive, :index

# Authentication
live "/auth/login", AuthLive, :login
live "/auth/callback", AuthLive, :callback
live "/auth/logout", AuthLive, :logout
get "/auth/store_session", AuthController, :store_session
get "/auth/clear_session", AuthController, :clear_session

# Movie Discovery
live "/movies", MovieListsLive, :index
live "/movies/:list_type", MovieListsLive, :show

# Reviews
live "/reviews", ReviewsLive, :index
live "/reviews/:filter", ReviewsLive, :show

# Media Details
live "/media/:type/:id", MovieDetailsLive, :show
```

### 2. Authenticated Web Routes (`/`)

**Pipeline**: `:authenticated` (requires valid TMDB session)

```elixir
# Personal List Management
live "/my-lists", UserMovieListsLive, :index
live "/my-lists/new", UserMovieListsLive, :new
live "/my-lists/:tmdb_list_id", UserMovieListLive, :show
live "/my-lists/:tmdb_list_id/edit", UserMovieListLive, :edit  # Automatically enters edit mode
```

### 3. Public List Sharing Routes (`/lists`)

**Pipeline**: `:browser` (no authentication required)

```elixir
# Public List Access
live "/lists/public/:tmdb_list_id", PublicListLive, :show
live "/lists/shared/:tmdb_list_id", SharedListLive, :show

# External Redirects
get "/lists/external/:tmdb_list_id", ListController, :external_redirect
```

### 4. Public API Routes (`/api`)

**Pipeline**: `:api` (JSON responses, no authentication required)

```elixir
# Read-only Public Access
get "/api/lists/public/:tmdb_list_id", Api.ListController, :show_public
get "/api/lists/shared/:tmdb_list_id", Api.ListController, :show_shared
```

### 5. Protected API Routes (`/api`)

**Pipeline**: `[:api, :require_auth]` (requires valid TMDB session)

```elixir
# Sync Operations (must come before parameterized routes)
post "/api/lists/sync", Api.SyncController, :sync_all_lists
get "/api/lists/sync/status", Api.SyncController, :sync_status
post "/api/lists/:tmdb_list_id/sync", Api.SyncController, :sync_list

# Queue Management (must come before parameterized routes)
get "/api/lists/queue", Api.QueueController, :index
post "/api/lists/queue/retry", Api.QueueController, :retry_all
get "/api/lists/queue/stats", Api.QueueController, :stats
post "/api/lists/queue/:operation_id/retry", Api.QueueController, :retry_operation
delete "/api/lists/queue/:operation_id", Api.QueueController, :cancel_operation

# TMDB List CRUD
post "/api/lists", Api.ListController, :create
get "/api/lists", Api.ListController, :index
get "/api/lists/:tmdb_list_id", Api.ListController, :show
put "/api/lists/:tmdb_list_id", Api.ListController, :update
delete "/api/lists/:tmdb_list_id", Api.ListController, :delete
post "/api/lists/:tmdb_list_id/clear", Api.ListController, :clear

# Movie Management
post "/api/lists/:tmdb_list_id/movies", Api.ListController, :add_movie
delete "/api/lists/:tmdb_list_id/movies/:tmdb_movie_id", Api.ListController, :remove_movie

# Sharing and Privacy
post "/api/lists/:tmdb_list_id/share", Api.ListController, :share
post "/api/lists/:tmdb_list_id/privacy", Api.ListController, :update_privacy
```

## Route Constraints

### TMDB List ID Constraint
```elixir
constraints: %{tmdb_list_id: ~r/\d+/}
```
- Ensures TMDB list IDs are integers
- Prevents invalid route matching
- Provides clear error messages for invalid IDs

### TMDB Movie ID Constraint
```elixir
constraints: %{tmdb_list_id: ~r/\d+/, tmdb_movie_id: ~r/\d+/}
```
- Ensures both list and movie IDs are integers
- Used in movie management endpoints

### Operation ID (UUID)
- Queue operation IDs use standard UUID format
- No explicit constraint needed as Phoenix handles UUID validation

## Pipeline Details

### `:browser` Pipeline
```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {FlixirWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug FlixirWeb.Plugs.AuthSession
end
```

**Features**:
- HTML content type acceptance
- Session and flash message handling
- CSRF protection
- Security headers
- Authentication context injection

### `:authenticated` Pipeline
```elixir
pipeline :authenticated do
  plug :browser
  plug FlixirWeb.Plugs.AuthSession, require_auth: true
end
```

**Features**:
- Inherits all browser pipeline features
- Enforces authentication requirement
- Redirects unauthenticated users to login
- Stores intended destination for post-login redirect

### `:api` Pipeline
```elixir
pipeline :api do
  plug :accepts, ["json"]
  plug :fetch_session
  plug FlixirWeb.Plugs.AuthSession
end
```

**Features**:
- JSON content type acceptance
- Session handling for API authentication
- Authentication context without enforcement

### `:require_auth` Pipeline
```elixir
pipeline :require_auth do
  plug FlixirWeb.Plugs.AuthSession, require_auth: true
end
```

**Features**:
- Enforces authentication for API endpoints
- Returns JSON error responses for unauthenticated requests
- Validates TMDB session on each request

## Route Ordering

Routes are carefully ordered to prevent conflicts:

1. **Static Routes First**: Non-parameterized routes (e.g., `/api/lists/sync`)
2. **Parameterized Routes**: Routes with parameters (e.g., `/api/lists/:tmdb_list_id`)
3. **Catch-all Routes**: Most general routes last (e.g., `/media/:type/:id`)

## Authentication Flow

### Web Authentication
1. User visits protected route
2. `AuthSession` plug checks for valid session
3. If unauthenticated, redirect to `/auth/login`
4. Store intended destination in session
5. After successful login, redirect to intended destination

### API Authentication
1. Client makes request to protected API endpoint
2. `AuthSession` plug validates session from cookie
3. If unauthenticated, return `401 Unauthorized` JSON response
4. If authenticated, proceed with request

## Error Handling

### Web Routes
- **404 Not Found**: Invalid routes or missing resources
- **403 Forbidden**: Access denied (authentication required)
- **500 Server Error**: Application errors

### API Routes
- **400 Bad Request**: Invalid request data
- **401 Unauthorized**: Authentication required
- **403 Forbidden**: Access denied
- **404 Not Found**: Resource not found
- **422 Unprocessable Entity**: Validation errors
- **500 Internal Server Error**: Server errors

## Route Testing

### Web Route Testing
```elixir
# Test authenticated route access
test "requires authentication for my-lists", %{conn: conn} do
  assert {:error, {:redirect, %{to: "/auth/login"}}} = 
    live(conn, "/my-lists")
end

# Test route with parameters
test "shows specific list", %{conn: authenticated_conn} do
  {:ok, _view, html} = live(authenticated_conn, "/my-lists/12345")
  assert html =~ "List Details"
end
```

### API Route Testing
```elixir
# Test API authentication
test "requires authentication for protected endpoint", %{conn: conn} do
  conn = get(conn, "/api/lists")
  assert json_response(conn, 401)
end

# Test route constraints
test "validates list ID format", %{conn: authenticated_conn} do
  conn = get(authenticated_conn, "/api/lists/invalid")
  assert response(conn, 404)
end
```

## Future Considerations

### API Versioning
Future API versions will be explicitly versioned:
```elixir
scope "/api/v2", FlixirWeb.Api.V2 do
  # Version 2 endpoints
end
```

### Subdomain Routing
Potential future support for subdomain-based routing:
```elixir
scope "/", FlixirWeb, host: "api." do
  # API-specific subdomain
end
```

### WebSocket Routes
Future real-time features may include WebSocket routes:
```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options]]
```

## Route Documentation Maintenance

When adding new routes:

1. **Update this documentation** with new route patterns
2. **Add route constraints** for parameter validation
3. **Update API documentation** for new endpoints
4. **Add comprehensive tests** for new routes
5. **Consider authentication requirements** and pipeline selection
6. **Verify route ordering** to prevent conflicts