# Flixir

A Phoenix LiveView web application for discovering movies and TV shows, powered by The Movie Database (TMDB) API. Features secure user authentication, comprehensive review systems, and curated movie lists. Built using [Kiro](https://kiro.dev/blog/introducing-kiro/) for enhanced development experience.

## Features

### 🎬 Movie & TV Show Discovery
- **Search**: Real-time search across movies and TV shows
- **Movie Lists**: Browse curated lists of popular, trending, top-rated, upcoming, and now playing movies
- **Filtering**: Filter results by media type (movies, TV shows, or all)
- **Sorting**: Sort by relevance, popularity, release date, or title
- **Navigation**: Click any search result to view detailed information and reviews
- **Detail Pages**: Dedicated pages for each movie and TV show with comprehensive information
- **Caching**: Intelligent caching system for improved performance

### ⭐ Reviews & Ratings System
- **Review Display**: Rich review cards with expandable content
- **Rating Statistics**: Comprehensive rating breakdowns and averages
- **Spoiler Protection**: Automatic spoiler detection and warnings
- **Interactive Elements**: Expandable reviews with "read more" functionality
- **Multi-source Support**: Aggregated ratings from multiple sources
- **Advanced Filtering**: Filter reviews by rating ranges, author names, and content keywords
- **Smart Sorting**: Sort reviews by date, rating, or author with ascending/descending options
- **Real-time Updates**: Live filtering and sorting without page reloads

### 🔐 Authentication System
- **TMDB Authentication**: Secure user authentication using TMDB's session-based system
- **Three-Step Flow**: Token creation → User approval → Session establishment
- **Session Management**: Persistent user sessions with automatic expiration handling
- **Secure Storage**: Encrypted session data with proper security measures
- **User Context**: Seamless integration of user authentication across the application
- **Privacy Protection**: GDPR-compliant session handling and data protection
- **Automatic Cleanup**: Background session cleanup for expired and idle sessions
- **Error Recovery**: Comprehensive error handling with retry mechanisms

### 🚀 Performance & UX
- **Real-time Updates**: Phoenix LiveView for seamless interactions
- **Responsive Design**: Tailwind CSS for mobile-first design
- **Error Handling**: Graceful error handling with retry mechanisms
- **Loading States**: Smooth loading indicators and transitions
- **Error Recovery**: One-click retry functionality for failed operations

## Testing

The application includes a comprehensive test suite covering all major components:

### Test Coverage
- **Unit Tests**: Individual module and function testing
- **Integration Tests**: End-to-end workflow testing including movie lists, authentication, and search
- **LiveView Tests**: Interactive component testing with Phoenix LiveViewTest
- **Component Tests**: UI component rendering and behavior testing
- **Performance Tests**: Load testing and response time validation
- **Security Tests**: Authentication flow and session security testing

### Running Tests
```bash
# Run all tests
mix test

# Run tests with coverage report
mix test --cover

# Run specific test file
mix test test/flixir_web/live/movie_lists_live_test.exs

# Run tests matching a pattern
mix test --grep "authentication"
```

### Test Categories
- **Authentication Tests**: Complete TMDB authentication flow testing including:
  - **End-to-End Flow**: Full authentication process from login initiation to session storage
  - **Error Scenarios**: Token creation failures, session creation errors, and network issues
  - **Session Management**: Session validation, expiration handling, and cleanup processes
  - **Security Testing**: CSRF protection, encrypted session storage, and logout verification
  - **Integration Testing**: Complete workflows with database operations and cookie management
- **Movie Lists Tests**: Comprehensive movie list functionality and UI testing
- **Search Tests**: Real-time search and filtering functionality
- **Review Tests**: Review display, filtering, and rating statistics
- **Cache Tests**: Caching behavior and performance validation
- **Error Handling Tests**: Comprehensive error scenario testing

## Getting Started

### Prerequisites
- Elixir ~> 1.15
- Phoenix ~> 1.8.0
- PostgreSQL
- TMDB API Key

### Installation

1. Clone the repository and install dependencies:
   ```bash
   mix setup
   ```

2. Configure your TMDB API key (authentication is now enabled by default):
   
   **Environment Variable (Required)**
   ```bash
   export TMDB_API_KEY="your_tmdb_api_key_here"
   ```
   
   The TMDB authentication configuration is now active in `config/runtime.exs` and will automatically use your API key for both movie data access and user authentication.

3. Run database migrations (includes authentication tables):
   ```bash
   mix ecto.migrate
   ```
   
   This will create the `auth_sessions` table required for TMDB authentication.

4. Start the Phoenix server:
   ```bash
   mix phx.server
   ```
   
   Or with interactive shell:
   ```bash
   iex -S mix phx.server
   ```

5. Visit [`localhost:4000`](http://localhost:4000) in your browser.

### Quick Start with Authentication

For a quick setup with authentication enabled:

```bash
# 1. Set up the project
mix setup

# 2. Set your TMDB API key
export TMDB_API_KEY="your_tmdb_api_key_here"

# 3. Start the server
mix phx.server

# 4. Visit http://localhost:4000 and click "Login" to test authentication
```

The authentication system will automatically:
- Create the necessary database tables
- Configure secure session management
- Handle TMDB authentication flow
- Provide user context throughout the application

### Authentication Setup

The application includes a comprehensive TMDB authentication system that allows users to log in with their TMDB credentials.

#### Authentication Flow

The authentication process follows TMDB's three-step authentication flow:

1. **Token Request**: Application requests a request token from TMDB
2. **User Approval**: User is redirected to TMDB to approve the token with their credentials
3. **Session Creation**: Approved token is exchanged for an authenticated session

#### Authentication Routes

- **Login**: `/auth/login` - Initiates the TMDB authentication flow
- **Callback**: `/auth/callback` - Handles the return from TMDB after user approval
- **Logout**: `/auth/logout` - Ends the user session and cleans up stored data

#### Authentication Configuration

The authentication system is configured through environment variables and is now **enabled by default** in the runtime configuration:

**Required Variables:**
```bash
# TMDB API key (required for all TMDB operations)
export TMDB_API_KEY="your_tmdb_api_key_here"
```

**Optional Variables:**
```bash
# TMDB API configuration
export TMDB_BASE_URL="https://api.themoviedb.org/3"  # Default TMDB API base URL
export TMDB_REDIRECT_URL="http://localhost:4000/auth/callback"  # Authentication callback URL

# Session configuration
export TMDB_SESSION_TIMEOUT="86400"  # Session lifetime in seconds (24 hours)
export SESSION_MAX_AGE="86400"  # Phoenix session cookie lifetime (24 hours)

# Session cleanup configuration
export SESSION_CLEANUP_INTERVAL="3600"  # Cleanup interval in seconds (1 hour)
export SESSION_MAX_IDLE="7200"  # Maximum idle time before session cleanup (2 hours)
```

#### Database Schema

The authentication system requires the `auth_sessions` table, which is created by running migrations:

```sql
CREATE TABLE auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_session_id VARCHAR(255) NOT NULL UNIQUE,
  tmdb_user_id INTEGER NOT NULL,
  username VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  last_accessed_at TIMESTAMP WITH TIME ZONE NOT NULL,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
```

#### Session Management

The application includes comprehensive session management features:

**Session Security:**
- **Encrypted Cookies**: All session data is stored in encrypted, signed cookies
- **HTTP-Only**: Cookies are marked HTTP-only to prevent XSS attacks
- **Secure Flag**: HTTPS-only cookies in production environments
- **SameSite Protection**: CSRF protection through SameSite cookie attributes

**Session Lifecycle:**
- **Automatic Validation**: Sessions are validated on every request
- **Expiration Handling**: Expired sessions are automatically cleaned up
- **Idle Timeout**: Sessions expire after periods of inactivity
- **Background Cleanup**: Periodic cleanup of expired sessions from the database

**Session Monitoring:**
```elixir
# Get session cleanup statistics
iex> Flixir.Auth.SessionCleanup.get_stats()

# Manually trigger session cleanup
iex> Flixir.Auth.SessionCleanup.cleanup_expired_sessions()
```

#### Authentication API

The authentication system provides a clean API for managing user sessions:

**Auth Context (`Flixir.Auth`):**
```elixir
# Start authentication flow
{:ok, auth_url} = Flixir.Auth.start_authentication()

# Complete authentication with approved token
{:ok, session} = Flixir.Auth.complete_authentication(approved_token)

# Validate existing session
{:ok, session} = Flixir.Auth.validate_session(session_id)

# Get current user information
{:ok, user} = Flixir.Auth.get_current_user(session_id)

# Logout and cleanup session
:ok = Flixir.Auth.logout(session_id)
```

**Session Plug (`FlixirWeb.Plugs.AuthSession`):**
The session plug automatically handles authentication state for all requests:

```elixir
# Conn assigns set by the plug
conn.assigns.current_user      # User data from TMDB or nil
conn.assigns.current_session   # Session struct or nil
conn.assigns.authenticated?    # Boolean authentication status
```

**LiveView Integration:**
Authentication state is automatically available in all LiveView components through the `AuthHooks` module:

```elixir
# Socket assigns available in LiveView
socket.assigns.current_user      # User data from TMDB or nil
socket.assigns.current_session   # Session struct or nil
socket.assigns.authenticated?    # Boolean authentication status
```

#### Error Handling

The authentication system includes comprehensive error handling:

**Error Types:**
- **Network Errors**: Automatic retry with exponential backoff
- **Rate Limiting**: Graceful handling of TMDB API rate limits
- **Token Expiration**: Automatic cleanup and re-authentication prompts
- **Session Expiration**: Transparent session renewal or re-authentication

**Error Recovery:**
- **User-Friendly Messages**: Clear error messages for different failure scenarios
- **Retry Mechanisms**: Automatic retry for transient failures
- **Fallback Strategies**: Graceful degradation when TMDB API is unavailable
- **Comprehensive Logging**: Detailed logging for debugging and monitoring

#### Security Considerations

**Production Security:**
- **HTTPS Only**: All authentication flows require HTTPS in production
- **Secure Cookies**: Production cookies are marked secure and HTTP-only
- **Session Encryption**: All session data is encrypted using Phoenix's secure session storage
- **CSRF Protection**: SameSite cookie attributes prevent CSRF attacks

**Secret Management:**
Generate secure secrets for production:
```bash
# Generate Phoenix secret key base
mix phx.gen.secret

# Generate session signing salt
mix phx.gen.secret

# Generate session encryption salt
mix phx.gen.secret
```

**Required Production Environment Variables:**
```bash
export SECRET_KEY_BASE="your_generated_secret_key_base"
export SESSION_SIGNING_SALT="your_generated_signing_salt"
export SESSION_ENCRYPTION_SALT="your_generated_encryption_salt"
export LIVEVIEW_SIGNING_SALT="your_generated_liveview_salt"
```

### Development Tools

The application includes several development and monitoring tools:

#### LiveDashboard
Access comprehensive application metrics and monitoring at [`localhost:4000/dev/dashboard`](http://localhost:4000/dev/dashboard) in development mode:
- **Metrics**: Request rates, response times, and system performance
- **Processes**: Live process monitoring and inspection
- **ETS Tables**: Database and cache inspection
- **Applications**: Application tree and supervision hierarchy
- **Request Logger**: Track and analyze HTTP requests with detailed timing information

The LiveDashboard is automatically configured for development environments using Phoenix's `dev_routes` configuration. It includes integrated telemetry metrics from `FlixirWeb.Telemetry` for comprehensive application monitoring.

#### Email Preview
View sent emails in development at [`localhost:4000/dev/mailbox`](http://localhost:4000/dev/mailbox) using Swoosh's mailbox preview.

#### Session Cleanup Monitoring
Monitor session cleanup statistics and manually trigger cleanup operations:
```elixir
# Get cleanup statistics
iex> Flixir.Auth.SessionCleanup.get_stats()

# Manually trigger cleanup
iex> Flixir.Auth.SessionCleanup.cleanup_expired_sessions()
```

### Configuration

The application includes comprehensive session management and LiveView configuration with secure defaults:

#### Endpoint Configuration
The Phoenix endpoint (`lib/flixir_web/endpoint.ex`) is configured with comprehensive LiveView and monitoring support:

**LiveView Socket Configuration:**
```elixir
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [session: @session_options]],
  longpoll: [connect_info: [session: @session_options]]
```

**Development Tools Integration:**
- **LiveDashboard**: Integrated request logging for performance monitoring
- **Live Reload**: Automatic browser refresh during development
- **Code Reloader**: Hot code reloading for faster development cycles

#### LiveView Configuration
Phoenix LiveView requires a signing salt for secure WebSocket connections. This is configured within the endpoint configuration:

```elixir
config :flixir, FlixirWeb.Endpoint,
  live_view: [signing_salt: "hLMifOvkqjrh1OjtczWMnigpiE95pC0c"]
```

This salt is used to sign LiveView tokens and should be changed in production for security. **Important**: Ensure there's only one `live_view` configuration per endpoint to avoid conflicts.

#### Session Configuration

#### Development Configuration
Base configuration in `config/config.exs`:
```elixir
config :flixir, FlixirWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: Flixir.PubSub,
  live_view: [signing_salt: "hLMifOvkqjrh1OjtczWMnigpiE95pC0c"],
  # Session configuration with security settings
  session: [
    store: :cookie,
    key: "_flixir_key",
    signing_salt: "session_salt_key_change_in_prod",
    encryption_salt: "session_encrypt_salt_change_in_prod",
    # 24 hours
    max_age: 86400,
    # Will be overridden in prod
    secure: false,
    http_only: true,
    same_site: "Lax"
  ]
```

Development overrides in `config/dev.exs`:
```elixir
config :flixir, FlixirWeb.Endpoint,
  session: [
    secure: false,  # Allow HTTP in development
    same_site: "Lax"
  ]
```

#### Production Configuration (`config/runtime.exs`)

The runtime configuration now includes **enabled TMDB authentication** by default:

```elixir
# TMDB Authentication configuration (now enabled)
config :flixir, :tmdb_auth,
  api_key: System.get_env("TMDB_API_KEY"),
  base_url: System.get_env("TMDB_BASE_URL") || "https://api.themoviedb.org/3",
  redirect_url: System.get_env("TMDB_REDIRECT_URL") || "http://localhost:4000/auth/callback",
  session_timeout: String.to_integer(System.get_env("TMDB_SESSION_TIMEOUT") || "86400")

# Session configuration
config :flixir, FlixirWeb.Endpoint,
  session: [
    secure: true,        # Require HTTPS in production
    http_only: true,     # Prevent XSS access to cookies
    same_site: "Strict", # Enhanced CSRF protection
    max_age: String.to_integer(System.get_env("SESSION_MAX_AGE") || "86400")
  ]
```

#### Security Features
- **Secure Cookies**: HTTP-only cookies prevent XSS attacks
- **CSRF Protection**: SameSite cookie attribute prevents CSRF attacks
- **Session Encryption**: All session data is encrypted using Phoenix's signed cookies
- **Configurable Expiration**: Session lifetime can be configured via environment variables
- **Production Security**: Enhanced security settings automatically applied in production

#### Important Security Notes
⚠️ **Production Deployment**: The default signing and encryption salts in `config/config.exs` are for development only. You must change these values in production:

```elixir
# Generate new salts for production
config :flixir, FlixirWeb.Endpoint,
  live_view: [signing_salt: System.get_env("LIVEVIEW_SIGNING_SALT") || "your_unique_liveview_salt"],
  session: [
    signing_salt: System.get_env("SESSION_SIGNING_SALT") || "your_unique_signing_salt",
    encryption_salt: System.get_env("SESSION_ENCRYPTION_SALT") || "your_unique_encryption_salt"
  ]
```

Generate secure salts using:
```bash
mix phx.gen.secret
```

**Required Environment Variables for Production:**
- `TMDB_API_KEY` - **Required**: Your TMDB API key for movie data access and authentication (now enabled by default)
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix secret key base for encryption
- `LIVEVIEW_SIGNING_SALT` - For LiveView WebSocket security
- `SESSION_SIGNING_SALT` - For session cookie signing
- `SESSION_ENCRYPTION_SALT` - For session cookie encryption

**Optional Environment Variables:**

*Server Configuration:*
- `PHX_HOST` - Production hostname (default: "example.com")
- `PORT` - Server port (default: 4000)
- `PHX_SERVER` - Set to "true" to start server in releases

*Session Configuration:*
- `SESSION_MAX_AGE` - Phoenix session cookie lifetime in seconds (default: 86400)
- `TMDB_SESSION_TIMEOUT` - TMDB session lifetime in seconds (default: 86400)
- `SESSION_CLEANUP_INTERVAL` - Session cleanup interval in seconds (default: 3600)
- `SESSION_MAX_IDLE` - Session idle timeout in seconds (default: 7200)

*TMDB API Configuration:*
- `TMDB_BASE_URL` - TMDB API base URL (default: "https://api.themoviedb.org/3") - **Now enabled by default**
- `TMDB_IMAGE_BASE_URL` - TMDB image base URL (default: "https://image.tmdb.org/t/p/w500")
- `TMDB_TIMEOUT` - TMDB API timeout in milliseconds (default: 5000)
- `TMDB_MAX_RETRIES` - TMDB API retry attempts (default: 3)

*Authentication Configuration:*
- `TMDB_REDIRECT_URL` - Authentication callback URL (default: "http://localhost:4000/auth/callback") - **Now enabled by default**

*Cache Configuration:*
- `SEARCH_CACHE_TTL` - Search cache TTL in seconds (default: 300)
- `SEARCH_CACHE_MAX_ENTRIES` - Maximum cache entries (default: 1000)
- `SEARCH_CACHE_CLEANUP_INTERVAL` - Cache cleanup interval in milliseconds (default: 60000)

*Database Configuration:*
- `POOL_SIZE` - Database connection pool size (default: 10)
- `ECTO_IPV6` - Set to "true" or "1" to enable IPv6 for database connections
- `DNS_CLUSTER_QUERY` - DNS cluster query for distributed deployments

#### Configuration Best Practices
- **Avoid Duplicates**: Ensure each configuration key appears only once per config block
- **Environment Separation**: Use environment-specific config files for different deployment environments
- **Secret Management**: Never commit production secrets to version control
- **Salt Generation**: Generate unique salts for each environment using `mix phx.gen.secret`
- **Validation**: Test configuration changes in development before deploying to production

## Architecture

### Core Modules

#### Auth Context (`lib/flixir/auth/`)
- **Session**: User session management with TMDB integration and automatic cleanup
- **SessionCleanup**: Background service for expired session cleanup
  - Automatic cleanup of expired and idle sessions
  - Configurable cleanup intervals (default: 1 hour)
  - Manual cleanup triggers with statistics tracking
  - Comprehensive logging and error handling
  - Session idle timeout detection (default: 2 hours)
- **TMDBClient**: TMDB authentication API client for token and session management
  - `create_request_token/0`: Initiates TMDB authentication flow by creating request tokens
  - `create_session/1`: Converts approved tokens into authenticated sessions
  - `delete_session/1`: Invalidates TMDB sessions for secure logout
  - `get_account_details/1`: Retrieves user account information from TMDB
  - Comprehensive error handling with retry logic and exponential backoff
  - Secure HTTP client configuration with proper timeouts and headers
- **ErrorHandler**: Comprehensive error handling for TMDB authentication operations
  - Classifies errors into user-friendly categories (network, rate limiting, authentication failures, etc.)
  - Implements retry logic with exponential backoff and jitter to prevent thundering herd
  - Provides both user-friendly and technical error messages for different audiences
  - Includes telemetry support for monitoring authentication issues and performance
  - Handles fallback strategies for different error types with appropriate logging levels
  - Supports context-aware error handling with operation tracking and attempt counting
- **Authentication Flow**: Three-step TMDB authentication (token → approval → session)
- **Security**: Secure session storage with encryption and proper expiration handling
- **Logging**: Comprehensive logging for authentication events, errors, and security monitoring

#### Authentication API Usage Patterns

**Basic Authentication Flow:**
```elixir
# 1. Start authentication (in LiveView or Controller)
case Flixir.Auth.start_authentication() do
  {:ok, auth_url} -> 
    # Redirect user to TMDB for approval
    {:noreply, redirect(socket, external: auth_url)}
  {:error, reason} -> 
    # Handle error (network issues, API unavailable, etc.)
    {:noreply, put_flash(socket, :error, "Authentication unavailable")}
end

# 2. Handle callback (after user approves on TMDB)
case Flixir.Auth.complete_authentication(approved_token) do
  {:ok, session} ->
    # Store session and redirect to intended destination
    conn = FlixirWeb.Plugs.AuthSession.put_session_id(conn, session.id)
    redirect(conn, to: "/dashboard")
  {:error, :token_denied} ->
    # User denied the request
    redirect(conn, to: "/auth/login?error=denied")
  {:error, reason} ->
    # Handle other errors
    redirect(conn, to: "/auth/login?error=failed")
end

# 3. Logout
case Flixir.Auth.logout(session_id) do
  :ok ->
    conn = FlixirWeb.Plugs.AuthSession.clear_session_id(conn)
    redirect(conn, to: "/")
  {:error, reason} ->
    # Log error but still clear local session
    Logger.warning("Logout error: #{inspect(reason)}")
    conn = FlixirWeb.Plugs.AuthSession.clear_session_id(conn)
    redirect(conn, to: "/")
end
```

**Session Validation:**
```elixir
# Validate session (automatically done by AuthSession plug)
case Flixir.Auth.validate_session(session_id) do
  {:ok, session} -> 
    # Session is valid, user is authenticated
    {:ok, user} = Flixir.Auth.get_current_user(session.tmdb_session_id)
  {:error, :session_expired} -> 
    # Session expired, clear and prompt re-authentication
    clear_session_and_redirect()
  {:error, :session_not_found} -> 
    # Invalid session, clear and continue as unauthenticated
    clear_session()
end
```

**Error Handling Patterns:**
```elixir
# Using the ErrorHandler for consistent error handling
case Flixir.Auth.TMDBClient.create_request_token() do
  {:ok, token_data} -> 
    # Success case
    handle_token(token_data)
  {:error, error} -> 
    # Use ErrorHandler for consistent error processing
    case Flixir.Auth.ErrorHandler.handle_error(error, :token_creation) do
      {:retry, delay} -> 
        # Schedule retry after delay
        Process.send_after(self(), :retry_token_creation, delay)
      {:user_error, message} -> 
        # Show user-friendly error
        put_flash(socket, :error, message)
      {:system_error, message} -> 
        # Log technical error, show generic message
        Logger.error("Token creation failed: #{message}")
        put_flash(socket, :error, "Authentication temporarily unavailable")
    end
end
```

**LiveView Authentication Patterns:**
```elixir
# Authentication state is automatically available via AuthHooks
defmodule MyAppWeb.SomeLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    # Authentication state is automatically set by AuthHooks
    if socket.assigns.authenticated? do
      # User is authenticated, show authenticated content
      {:ok, assign(socket, :user_content, load_user_content(socket.assigns.current_user))}
    else
      # User not authenticated, show public content
      {:ok, assign(socket, :public_content, load_public_content())}
    end
  end

  def handle_event("login", _params, socket) do
    case Flixir.Auth.start_authentication() do
      {:ok, auth_url} -> {:noreply, redirect(socket, external: auth_url)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Login unavailable")}
    end
  end
end
```

**Session Monitoring and Cleanup:**
```elixir
# Monitor session statistics
iex> Flixir.Auth.SessionCleanup.get_stats()
%{
  total_sessions: 150,
  expired_sessions: 12,
  idle_sessions: 8,
  last_cleanup: ~U[2024-01-15 10:30:00Z],
  cleanup_interval: 3600
}

# Manual cleanup (useful for maintenance)
iex> Flixir.Auth.SessionCleanup.cleanup_expired_sessions()
{:ok, %{cleaned: 20, errors: 0}}

# Check specific session
iex> Flixir.Auth.validate_session("session-uuid")
{:ok, %Flixir.Auth.Session{username: "user123", expires_at: ~U[2024-01-16 10:00:00Z]}}
```

#### Media Context (`lib/flixir/media/`)
- **SearchResult**: Data structure for search results and movie lists
- **TMDBClient**: API client for The Movie Database with movie list endpoints
- **Cache**: High-performance caching layer with specialized movie list caching
- **Movie Lists**: Five curated movie list functions with caching and error handling

#### Reviews Context (`lib/flixir/reviews/`)
- **Review**: Individual review data structure with comprehensive validation
- **RatingStats**: Aggregated rating statistics with percentage distributions
- **Cache**: Review-specific caching system with TTL management
- **TMDBClient**: Review-focused API operations with error handling
- **ErrorHandler**: Centralized error handling for review operations
- **Future Implementation**: Comprehensive review system ready for TMDB reviews API integration

#### Web Components (`lib/flixir_web/components/`)
- **SearchComponents**: Interactive search interface with clickable result cards
- **ReviewComponents**: Review cards, rating displays, and interactive elements
- **ReviewFilters**: Advanced filtering and sorting controls for reviews
- **MovieListComponents**: Comprehensive UI components for movie list display and navigation
- **MainNavigation**: Primary navigation component with unified navigation across search, movies, and reviews sections
  - Provides consistent navigation experience across all sections
  - Supports both main navigation and secondary sub-navigation
  - Includes active state highlighting and responsive design
  - Features brand logo with navigation to home page

#### LiveView Modules (`lib/flixir_web/live/`)
- **AuthLive**: Comprehensive user authentication interface with TMDB integration
  - **Authentication Flow**: Complete TMDB three-step authentication (token → approval → session)
  - **Route Handling**: Supports login, callback, and logout routes with parameter validation
  - **Session Management**: Secure session storage and retrieval with cookie integration
  - **Async Operations**: Non-blocking authentication operations using Phoenix async assigns with enhanced result handling
  - **Robust Processing**: Improved async result handlers that support both direct and nested response formats for maximum compatibility
  - **Error Recovery**: Comprehensive error handling with user-friendly messages and retry functionality
  - **State Management**: Loading states, success/error messages, and proper UI feedback
  - **Security Integration**: Works seamlessly with `AuthSession` plug for session management
  - **User Experience**: Smooth redirects, flash messages, and preserved navigation context
- **SearchLive**: Real-time search interface with filtering and sorting
  - **Authentication Integration**: Uses `on_mount` hook pattern for automatic authentication state management
  - **Simplified State Handling**: Authentication state is automatically injected via `AuthHooks` module
  - **Clean Architecture**: Removed manual authentication state handling in favor of centralized hook system
- **MovieDetailsLive**: Movie and TV show detail pages with review management and error recovery
  - Handles dynamic routing for both movies and TV shows
  - Converts string media types from URL parameters to atoms for API compatibility
  - Provides comprehensive error handling and retry functionality for failed operations
- **MovieListsLive**: Curated movie lists interface with navigation and pagination
  - Displays popular, trending, top-rated, upcoming, and now playing movies
  - Tab-based navigation between different list types with URL routing
  - Infinite scroll pagination with load more functionality
  - Real-time error handling and retry mechanisms
  - Responsive design optimized for all screen sizes
- **ReviewsLive**: Review browsing interface with filtering capabilities (future implementation)
  - Supports multiple filter types: recent, popular, movies, TV shows, and top-rated reviews
  - URL parameter handling for filter type and pagination
  - Authentication-aware interface with user context integration
  - Prepared for comprehensive review display and management features

#### LiveView Authentication Hooks (`lib/flixir_web/live/auth_hooks.ex`)
The `AuthHooks` module provides centralized authentication state management for all LiveView components:

**Core Functionality:**
- **Centralized State Management**: Automatically transfers authentication state from HTTP connection to LiveView socket
- **Session Validation**: Validates session IDs from Phoenix sessions against the database on every LiveView mount
- **Automatic Assignment**: Ensures authentication assigns are consistently available across all LiveViews
- **Clean Architecture**: Eliminates the need for manual authentication state handling in individual LiveView modules

**Implementation Benefits:**
- **DRY Principle**: Removes duplicate authentication code from individual LiveView modules like `SearchLive`
- **Consistency**: Ensures all LiveViews have the same authentication state structure
- **Maintainability**: Centralizes authentication logic for easier updates and debugging
- **Performance**: Efficient session validation with proper error handling and fallbacks

**Debug Features:**
- **Session Monitoring**: Logs session keys and authentication state during LiveView mounting
- **State Validation**: Detects mismatches between session data and authentication state
- **Issue Detection**: Identifies potential problems with the AuthSession plug integration
- **Comprehensive Logging**: Both Logger and IO.puts output for development debugging

**Usage:**
```elixir
# In router.ex - automatically applied to LiveView routes
live_session :default, on_mount: [{FlixirWeb.AuthHooks, :default}] do
  live "/", SearchLive, :index
  live "/movies", MovieListsLive, :index
  # ... other LiveView routes
end
```

**Socket Assigns Set:**
- `:authenticated?` - Boolean indicating authentication status
- `:current_user` - User data from TMDB API or nil
- `:current_session` - Session struct from database or nil

**Recent Improvements:**
- **SearchLive Integration**: Updated `SearchLive` to use the centralized hook system instead of manual authentication state handling
- **Code Simplification**: Removed redundant authentication code from individual LiveView modules
- **Improved Reliability**: Consistent authentication state management across all LiveView components

#### Session Management (`lib/flixir_web/plugs/auth_session.ex`)
The `AuthSession` plug provides comprehensive session management and authentication validation:

**Core Functionality:**
- **Session Validation**: Validates TMDB session IDs from cookies against the database
- **User Context Injection**: Automatically injects current user data and session information into conn assigns
- **Automatic Cleanup**: Handles expired sessions with automatic cookie cleanup
- **Authentication Requirements**: Optional authentication enforcement with configurable redirect behavior
- **Security Logging**: Comprehensive logging for authentication events and security monitoring

**Session Configuration:**
The application uses Phoenix's built-in session management with enhanced security settings:
- **Cookie-based Storage**: Sessions are stored in encrypted, signed cookies
- **Security Headers**: HTTP-only, secure, and SameSite attributes for CSRF protection
- **Configurable Expiration**: 24-hour default session lifetime (configurable via environment)
- **Environment-specific Settings**: Development uses relaxed settings, production enforces HTTPS
- **Automatic Cleanup**: Expired sessions are automatically cleaned from both cookies and database

**Plug Configuration:**
```elixir
# Optional authentication (default)
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug FlixirWeb.Plugs.AuthSession
  # ... other plugs
end

# Required authentication
pipeline :authenticated do
  plug :browser
  plug FlixirWeb.Plugs.AuthSession, require_auth: true
end

# Custom redirect path
pipeline :admin do
  plug :browser
  plug FlixirWeb.Plugs.AuthSession, 
    require_auth: true, 
    redirect_to: "/admin/login"
end
```

**Conn Assigns:**
The plug sets the following assigns on every request:
- `:current_user` - Map of current user data from TMDB API, or `nil` if not authenticated
- `:current_session` - Session struct from database, or `nil` if no valid session
- `:authenticated?` - Boolean indicating if the user has a valid authenticated session

**Helper Functions:**
- `put_session_id/2` - Stores session ID in cookie after successful authentication
- `clear_session_id/1` - Removes session from cookie during logout
- `get_redirect_after_login/1` - Retrieves stored redirect path for post-login navigation
- `clear_redirect_after_login/1` - Clears redirect path after successful redirect

**Session Lifecycle:**
1. **Validation**: Checks for session ID in cookie and validates against database
2. **User Data**: Retrieves fresh user data from TMDB API for valid sessions
3. **Expiration Handling**: Automatically clears expired or invalid sessions
4. **Context Injection**: Makes user data available throughout the application
5. **Redirect Logic**: Handles authentication requirements and post-login navigation

**Security Features:**
- **Session Encryption**: Uses Phoenix's secure session storage
- **Automatic Expiration**: Respects TMDB session lifetime and database expiration
- **Invalid Session Cleanup**: Removes stale sessions from cookies automatically
- **Request Path Preservation**: Stores intended destination for post-login redirect
- **Comprehensive Logging**: Tracks authentication events for security monitoring

#### Routing & Navigation (`lib/flixir_web/router.ex`)
The application uses Phoenix pipelines with integrated authentication middleware and clean LiveView socket configuration:

**Pipeline Configuration:**
```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {FlixirWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug FlixirWeb.Plugs.AuthSession  # Automatic session validation
end

pipeline :authenticated do
  plug :browser
  plug FlixirWeb.Plugs.AuthSession, require_auth: true  # Required authentication
end

pipeline :api do
  plug :accepts, ["json"]
end
```

**Development Tools Configuration:**
The router includes proper configuration for development tools using Phoenix's recommended approach:

```elixir
# Enable LiveDashboard and Swoosh mailbox preview in development
if Application.compile_env(:flixir, :dev_routes) do
  import Phoenix.LiveDashboard.Router

  scope "/dev" do
    pipe_through :browser

    live_dashboard "/dashboard", metrics: FlixirWeb.Telemetry
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end
```

This configuration ensures that development tools are:
- **Environment-Specific**: Only available when `:dev_routes` is enabled in configuration
- **Secure**: Automatically excluded from production builds
- **Integrated**: Includes telemetry metrics and email preview functionality
- **Properly Scoped**: Uses the `/dev` path prefix for clear separation from application routes

**Recent Router Improvements:**
- Cleaned up unused imports for better maintainability
- Streamlined route organization with consistent formatting
- Removed unnecessary whitespace for improved code clarity
- Consolidated development tools configuration using Phoenix best practices

**Application Routes:**
- **Home Route**: `/` - Landing page with SearchLive for immediate search functionality
- **Search Route**: `/search` - Main search interface with LiveView and URL parameter support
- **Authentication Routes**:
  - `/auth/login` - User login interface with TMDB authentication initiation
  - `/auth/callback` - TMDB authentication callback handler with token processing
  - `/auth/logout` - User logout interface with session cleanup confirmation
  - `/auth/store_session` - Session storage endpoint for post-authentication handling
  - `/auth/clear_session` - Session cleanup endpoint for logout processing
- **Movie Lists Routes**: 
  - `/movies` - Popular movies (default list)
  - `/movies/:list_type` - Specific movie lists (trending, top-rated, upcoming, now-playing)
  - URL parameters: `?page=N` for pagination support
- **Reviews Routes**: 
  - `/reviews` - Recent reviews (default filter)
  - `/reviews/:filter` - Filtered reviews (popular, movies, tv, top-rated)
- **Detail Routes**: `/media/:type/:id` - Dynamic LiveView routes for movie and TV show details with review integration
- **URL Parameters**: Shareable search states with query, filter, and sort parameters
- **Mixed Navigation**: Combines HTTP GET routes and LiveView for optimal performance and user experience
- **Session Management**: All routes automatically validate user sessions via `AuthSession` plug
- **Protected Routes**: Future authenticated-only features can use the `:authenticated` pipeline
- **Development Tools**: 
  - LiveDashboard available at `/dev/dashboard` with comprehensive telemetry metrics
  - Email preview available at `/dev/mailbox` for development email testing
  - Both tools are automatically configured via Phoenix's `dev_routes` system

**Movie Lists Routing:**
The router now includes dedicated routes for the movie lists functionality:
```elixir
live "/movies", MovieListsLive, :index
live "/movies/:list_type", MovieListsLive, :show
```

**Supported List Types:**
- `popular` - Most popular movies (default when accessing `/movies`)
- `trending` - Movies trending this week
- `top-rated` - Highest rated movies of all time
- `upcoming` - Movies coming soon to theaters
- `now-playing` - Movies currently playing in theaters

**Template Helper Functions:**
The MovieListsLive module includes comprehensive template helper functions for:
- **Navigation**: Dynamic URL building and list type parameter conversion
- **Display**: Movie poster URLs with multiple sizes and responsive srcsets
- **Formatting**: Release date formatting and text truncation utilities
- **Error Handling**: User-friendly error message formatting for different error types
- **Internationalization**: Consistent labeling and descriptions for all movie list types

#### Navigation System (`lib/flixir_web/components/main_navigation.ex`)
The application features a comprehensive navigation system built around the `MainNavigation` component:

**Main Navigation Features:**
- **Unified Navigation**: Consistent navigation experience across search, movies, and reviews sections
- **Active State Management**: Visual indicators for current section and subsection
- **Responsive Design**: Mobile-friendly navigation with proper touch targets and overflow handling
- **Brand Integration**: Prominent Flixir logo with home page navigation
- **Authentication Integration**: Dynamic display of login button or user menu based on authentication state
- **Accessibility**: Proper ARIA labels, semantic HTML, keyboard navigation, and test IDs

**Navigation Components:**
- **`main_nav/1`**: Primary navigation bar with search, movies, and reviews sections
- **`sub_nav/1`**: Secondary navigation for subsections within each main section
- **`user_menu/1`**: Authenticated user menu with username display and logout functionality
- **`login_button/1`**: Login button for unauthenticated users
- **`nav_item/1`**: Private component for individual navigation items with icons, labels, and descriptions

**Authentication States:**
The navigation automatically adapts based on user authentication status:
- **Unauthenticated**: Shows login button linking to `/auth/login`
- **Authenticated**: Shows user menu with username, full name (if available), and logout option
- **User Menu Features**: Dropdown menu with user information and logout functionality
- **Seamless Integration**: Works with the `AuthSession` plug for automatic state management

**Component Usage:**
```heex
<!-- Main navigation with authentication state -->
<.main_nav 
  current_section={:movies}
  current_user={@current_user}
  authenticated?={@authenticated?}
/>

<!-- Sub-navigation for movie lists -->
<.sub_nav 
  items={[
    {:popular, "Popular", "/movies", "Most popular movies"},
    {:trending, "Trending", "/movies/trending", "Trending this week"},
    {:top_rated, "Top Rated", "/movies/top-rated", "Highest rated movies"}
  ]}
  current={:popular}
/>

<!-- Standalone user menu for authenticated users -->
<.user_menu current_user={@current_user} />

<!-- Standalone login button for unauthenticated users -->
<.login_button />
```

**Visual Design:**
- Clean, modern interface with subtle shadows and borders
- Blue accent color for active states and brand elements
- Smooth transitions and hover effects
- Responsive grid layout that adapts to different screen sizes
- Consistent spacing and typography throughout
- User menu with proper dropdown styling and hover states

## Error Handling & Monitoring

The application includes comprehensive error handling and monitoring systems:

### Error Handling Strategy
- **Graceful Degradation**: Application continues to function even when external services are unavailable
- **User-Friendly Messages**: Technical errors are translated into actionable user messages
- **Retry Mechanisms**: Automatic retry logic for transient failures with exponential backoff
- **Fallback Behavior**: Cached data and alternative flows when primary services fail

### Error Types & Handling
- **Network Errors**: Connection timeouts, DNS failures, and network unreachability
- **API Errors**: TMDB API rate limiting, authentication failures, and service unavailability
- **Authentication Errors**: Session expiration, invalid tokens, and authorization failures
- **Data Errors**: Malformed responses, missing data, and transformation failures
- **Cache Errors**: Cache misses, serialization failures, and cleanup errors

### Monitoring & Observability
- **Comprehensive Logging**: Structured logging for all major operations and errors
- **Performance Metrics**: Response times, cache hit rates, and API call statistics
- **Session Monitoring**: Authentication events, session lifecycle, and security alerts
- **Error Tracking**: Detailed error context with request IDs and user information
- **Health Checks**: Application health monitoring and dependency status

### Development Debugging
- **Debug Logging**: Enhanced logging in development mode with detailed context
- **Authentication Debugging**: Specialized debugging for authentication flow issues
- **Session State Inspection**: Tools for inspecting session state and authentication context
- **Cache Statistics**: Real-time cache performance and hit rate monitoring

### Key Features Implementation

#### Review System
The review system provides comprehensive review management with:

- **Review Cards**: Interactive cards with expandable content, spoiler warnings, and author information
- **Rating Statistics**: Visual rating breakdowns with percentage distributions
- **Caching**: Intelligent caching for both individual reviews and aggregated statistics
- **Advanced Filtering & Sorting**: Comprehensive filtering and sorting system with real-time updates

##### Review Filtering & Sorting Features
The `ReviewFilters` component provides powerful filtering capabilities:

**Sorting Options:**
- Sort by date, rating, or author name
- Toggle between ascending and descending order
- Visual indicators for active sort settings

**Rating Filters:**
- Filter by positive reviews (6+ stars) or negative reviews (< 6 stars)
- Custom rating ranges: High (8-10), Medium (5-7), Low (1-4)
- Support for all ratings or specific rating criteria

**Content Filters:**
- Search within review content using keywords
- Filter by author name with partial matching
- Real-time filtering with debounced input for performance

**Interactive Features:**
- Active filter badges with one-click removal
- Clear all filters functionality
- Live count of filtered vs. total reviews
- Responsive design for mobile and desktop
- Proper form handling with Phoenix LiveView integration

**Recent Improvements:**
- Enhanced rating breakdown display logic that ensures rating distributions are only shown when there are actual reviews with ratings available
- Improved form structure with proper form wrapper for better event handling and accessibility
- Optimized filter control organization for better user experience
- Fixed duplicate event handlers in sort controls for cleaner event handling and improved performance

#### Search & Discovery
- **Real-time Search**: Debounced search with instant results
- **Interactive Results**: Clickable search result cards that navigate to detail pages
- **Advanced Filtering**: Filter by media type with visual indicators
- **Smart Sorting**: Multiple sorting options with URL persistence
- **Shareable URLs**: Query parameters for bookmarkable search states
- **Responsive Design**: Optimized grid layout for all screen sizes
- **Loading States**: Skeleton cards and smooth transitions during search
- **Empty States**: Helpful suggestions when no results are found

#### Movie Lists System
The application features a comprehensive movie lists system with both backend API and frontend UI components:

##### Movie Lists API
**Available Movie Lists:**
- **Popular Movies**: `Flixir.Media.get_popular_movies/1` - Currently popular movies
- **Trending Movies**: `Flixir.Media.get_trending_movies/1` - Trending movies (daily or weekly)
- **Top Rated Movies**: `Flixir.Media.get_top_rated_movies/1` - Highest rated movies
- **Upcoming Movies**: `Flixir.Media.get_upcoming_movies/1` - Soon-to-be-released movies
- **Now Playing**: `Flixir.Media.get_now_playing_movies/1` - Currently in theaters

**API Features:**
- **Consistent Interface**: All functions follow the same pattern with options support
- **Flexible Return Formats**: Support for both legacy list format and new map format with pagination
- **Intelligent Caching**: 15-minute TTL for movie lists (longer than search results)
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Pagination Support**: Built-in pagination with `has_more` indicators and load more functionality
- **Cache Format Compatibility**: Handles both legacy list format and new map format cached results

**Usage Examples:**
```elixir
# Get popular movies (legacy format)
{:ok, movies} = Flixir.Media.get_popular_movies()

# Get trending movies with pagination info
{:ok, %{results: movies, has_more: true}} = 
  Flixir.Media.get_trending_movies(return_format: :map, time_window: "day")

# Get top rated movies for page 2
{:ok, movies} = Flixir.Media.get_top_rated_movies(page: 2)

# Get upcoming movies with map format
{:ok, %{results: movies, has_more: false}} = 
  Flixir.Media.get_upcoming_movies(return_format: :map, page: 3)
```

**TMDB Integration:**
- Direct integration with TMDB movie list endpoints
- Automatic transformation to `SearchResult` structs for consistency
- Proper media type handling (all results marked as `:movie`)
- Robust error handling for API failures and network issues
- Smart pagination detection with fallback logic for responses without pagination info

##### Movie Lists UI Components
The `MovieListComponents` module provides a complete UI system for displaying movie lists:

**Core Components:**
- **`movie_lists_container/1`**: Main container with navigation, content area, and state management
- **`list_navigation/1`**: Tab-based navigation between different movie list types
- **`movie_grid/1`**: Responsive grid layout for movie cards
- **`movie_card/1`**: Individual movie cards with posters, ratings, and metadata

**Visual Features:**
- **Responsive Design**: Adaptive grid layout (1-5 columns based on screen size)
- **Interactive Cards**: Hover effects, smooth transitions, and click navigation
- **Rich Metadata**: Movie posters, titles, release dates, ratings, and popularity indicators
- **Visual Indicators**: Special badges for trending and upcoming movies
- **Loading States**: Skeleton cards and loading spinners for smooth UX

**Navigation & Context:**
- **Tab Navigation**: Clean tab interface for switching between list types
- **Context Preservation**: Navigation parameters maintain list context when viewing movie details
- **URL Integration**: Designed for integration with routing (`/movies/:list_type`)
- **Back Navigation**: Preserves user's position when returning from detail pages

**State Management:**
- **Loading States**: Comprehensive loading indicators and skeleton screens
- **Error States**: User-friendly error messages with retry functionality
- **Empty States**: Helpful messaging when no movies are available
- **Pagination**: Load more functionality with visual feedback

**Accessibility & Performance:**
- **Semantic HTML**: Proper ARIA labels and semantic structure
- **Image Optimization**: Responsive images with srcset and lazy loading
- **Performance**: Optimized rendering with efficient data structures
- **Mobile-First**: Touch-friendly interface optimized for mobile devices

**Component Usage:**
```heex
<!-- Main movie lists container -->
<.movie_lists_container
  current_list={:popular}
  movies={@movies}
  loading={@loading}
  error={@error}
  has_more={@has_more}
  page={@page}
/>

<!-- Individual movie card -->
<.movie_card 
  movie={movie} 
  current_list={:trending} 
/>

<!-- Navigation tabs -->
<.list_navigation current_list={:top_rated} />
```

## Deployment

### Production Deployment
The application is designed for production deployment with comprehensive security and performance optimizations:

#### Security Considerations
- **HTTPS Enforcement**: All production traffic must use HTTPS
- **Secure Headers**: Comprehensive security headers including CSP, HSTS, and X-Frame-Options
- **Session Security**: Encrypted sessions with secure cookies and CSRF protection
- **API Key Management**: Secure environment variable handling for sensitive credentials
- **Database Security**: Connection encryption and proper access controls

#### Performance Optimizations
- **Asset Optimization**: Minified CSS and JavaScript with proper caching headers
- **Database Optimization**: Connection pooling and query optimization
- **Caching Strategy**: Multi-layer caching with configurable TTL values
- **CDN Integration**: Ready for CDN deployment of static assets
- **Monitoring**: Built-in telemetry and metrics collection

#### Scaling Considerations
- **Horizontal Scaling**: Stateless design supports multiple application instances
- **Database Scaling**: Connection pooling and read replica support
- **Cache Scaling**: Distributed caching support for multi-instance deployments
- **Session Management**: Database-backed sessions for multi-instance compatibility

### Docker Deployment
The application can be containerized for Docker deployment:

```dockerfile
# Example Dockerfile structure
FROM elixir:1.15-alpine AS build
# Build steps...

FROM alpine:3.18 AS runtime
# Runtime configuration...
```

### Environment Setup
Ensure all required environment variables are configured in your production environment:
- Use secure secret generation for all salt values
- Configure proper database connection strings
- Set up monitoring and logging infrastructure
- Implement backup and disaster recovery procedures

## Development Workflow

### Code Quality
The project maintains high code quality standards:

```bash
# Format code according to Elixir standards
mix format

# Check code formatting
mix format --check-formatted

# Run comprehensive test suite
mix test --cover

# Run specific test categories
mix test --grep "authentication"
mix test --grep "movie_lists"
```

### Development Guidelines
- **Testing**: All new features must include comprehensive tests
- **Documentation**: Update README.md and inline documentation for significant changes
- **Error Handling**: Implement proper error handling with user-friendly messages
- **Security**: Follow security best practices for authentication and data handling
- **Performance**: Consider caching and optimization for user-facing features

### Architecture Decisions
- **Phoenix LiveView**: Used for real-time, interactive user interfaces
- **Context Pattern**: Business logic organized in bounded contexts (Auth, Media, Reviews)
- **Component-Based UI**: Reusable components for consistent user experience
- **Comprehensive Testing**: Unit, integration, and performance testing strategies
- **Security-First**: Authentication and session management with security as a priority

### Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with proper tests and documentation
4. Ensure all tests pass (`mix test`)
5. Format your code (`mix format`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is built with Phoenix Framework and follows standard Elixir/Phoenix conventions. See the Phoenix Framework documentation for more information about the underlying technologies.

---

**Built with ❤️ using Phoenix LiveView and Elixir**

#### Authentication System Implementation
The application implements a comprehensive TMDB-based authentication system with seamless session management:

**Authentication Flow:**
1. **Token Request**: `TMDBClient.create_request_token/0` requests a token from TMDB API
2. **User Authorization**: User is redirected to TMDB to approve the application
3. **Session Creation**: `TMDBClient.create_session/1` exchanges approved token for session ID
4. **Session Storage**: Session data is securely stored in the database with encryption
5. **Account Integration**: `TMDBClient.get_account_details/1` retrieves user profile information
6. **Session Management**: `TMDBClient.delete_session/1` handles secure logout and cleanup

**AuthLive Implementation:**
The `AuthLive` module provides a complete user interface for the authentication system:

- **Route Management**: Handles `/auth/login`, `/auth/callback`, and `/auth/logout` routes
- **Async Authentication**: Uses Phoenix async assigns for non-blocking authentication operations with improved result handling
- **Robust Result Processing**: Enhanced async result handlers that support both direct and nested response formats for maximum compatibility
- **Token Processing**: Securely processes TMDB callback tokens and handles approval/denial scenarios
- **Session Integration**: Seamlessly integrates with the `AuthSession` plug for cookie management
- **Error Handling**: Comprehensive error formatting with user-friendly messages for all failure scenarios
- **State Management**: Proper loading states, success messages, and error recovery mechanisms
- **Navigation Context**: Preserves user's intended destination and handles post-login redirects
- **Security Logging**: Comprehensive logging for authentication events and security monitoring

**Session Middleware Integration:**
The `AuthSession` plug provides seamless authentication integration across the entire application:
- **Automatic Validation**: Every request validates the user's session against the database
- **Fresh User Data**: Retrieves current user information from TMDB API for valid sessions
- **Context Injection**: Makes user data available in all LiveView components and controllers
- **Transparent Operation**: Works behind the scenes without requiring explicit session checks
- **Flexible Configuration**: Supports both optional and required authentication per route

**Security Features:**
- **Secure Cookies**: HTTP-only, secure, and SameSite cookie configuration
- **Session Encryption**: All session data is encrypted using Phoenix's signed cookies with configurable salts
- **Automatic Expiration**: Sessions automatically expire based on TMDB session lifetime (24 hours default)
- **Background Cleanup**: Expired sessions are cleaned up automatically with database cleanup
- **CSRF Protection**: Built-in CSRF protection for authentication forms with SameSite cookie attributes
- **Session Invalidation**: Automatic cleanup of invalid or expired sessions from cookies
- **Environment-specific Security**: Production enforces HTTPS-only cookies and strict SameSite policy
- **Configurable Session Lifetime**: Session duration can be customized via `SESSION_MAX_AGE` environment variable

**Database Integration:**
- **Session Persistence**: User sessions are stored in the `auth_sessions` table with proper indexing
- **Performance Optimization**: Indexed queries for fast session validation and user lookups
- **Data Integrity**: Foreign key constraints and proper data validation with session expiration
- **Privacy Compliance**: GDPR-compliant session handling and data retention policies
- **Concurrent Access**: Handles multiple concurrent sessions per user with proper isolation

**Logging & Monitoring:**
- **Authentication Events**: Comprehensive logging of login, logout, and session validation events
- **Security Monitoring**: Failed authentication attempts and suspicious activity logging
- **Error Tracking**: Detailed error logging for debugging and monitoring authentication issues
- **User Activity**: Session validation and access pattern logging for security analysis
- **Performance Monitoring**: Session validation timing and database query performance tracking

**User Experience:**
- **Seamless Integration**: Authentication state is maintained across all LiveView components automatically
- **Error Handling**: Comprehensive error handling for authentication failures with user-friendly messages
- **Session Management**: Automatic session refresh and logout functionality with proper cleanup
- **User Context**: User information is available throughout the application via conn assigns
- **Redirect Handling**: Preserves intended destination and redirects users after successful authentication

## Configuration

### Environment Variables

The application supports the following environment variables for configuration:

#### Required Variables
- `TMDB_API_KEY` - Your TMDB API key for accessing movie data
- `DATABASE_URL` - PostgreSQL database connection string (production)
- `SECRET_KEY_BASE` - Phoenix secret key base for encryption (production)

#### Optional Variables
- `SESSION_MAX_AGE` - Session lifetime in seconds (default: 86400 = 24 hours)
- `TMDB_REDIRECT_URL` - TMDB authentication callback URL (default: http://localhost:4000/auth/callback)
- `TMDB_SESSION_TIMEOUT` - TMDB session timeout in seconds (default: 86400)
- `SESSION_CLEANUP_INTERVAL` - Database session cleanup interval in seconds (default: 3600)
- `SESSION_MAX_IDLE` - Maximum idle time before session expires (default: 7200)
- `SEARCH_CACHE_TTL` - Search result cache TTL in seconds (default: 300)
- `TMDB_TIMEOUT` - TMDB API request timeout in milliseconds (default: 5000)
- `TMDB_MAX_RETRIES` - Maximum retry attempts for TMDB API calls (default: 3)

#### Session Security Configuration
The session configuration automatically adapts based on the environment:

**Development:**
- `secure: false` - Allows HTTP connections for local development
- `same_site: "Lax"` - Relaxed CSRF protection for development workflow
- `http_only: true` - Prevents XSS access to cookies
- Fixed signing and encryption salts (should be changed in production)

**Production:**
- `secure: true` - Requires HTTPS connections for security
- `same_site: "Strict"` - Enhanced CSRF protection in production
- `http_only: true` - Prevents XSS access to cookies
- Environment-based session lifetime configuration via `SESSION_MAX_AGE`

#### Error Handling & Recovery
The application provides robust error handling with user-friendly recovery options:

**Error Types Handled:**
- Network timeouts and connection failures
- API rate limiting and authentication errors
- Service unavailability and server errors
- Data transformation and parsing errors
- Authentication failures and session expiration

**Recovery Mechanisms:**
- **Retry Functionality**: One-click retry buttons for failed operations
- **Graceful Degradation**: Partial functionality when some services fail
- **User Feedback**: Clear error messages with actionable guidance
- **State Preservation**: Maintains user context during error recovery
- **Authentication Recovery**: Automatic re-authentication prompts for expired sessions

**Implementation Details:**
- The `MovieDetailsLive` module includes a `retry_reviews` event handler
- Error states are clearly displayed with contextual retry options
- Loading states prevent duplicate requests during recovery
- Error messages are formatted for user comprehension
- Authentication errors trigger appropriate login flows

## Recent Updates

### Code Quality Improvements

**Debug Statement Cleanup**
- **SearchLive Module**: Removed temporary debug statement (`IO.puts authenticated?`) from the mount function
- **Code Quality**: Implemented development guidelines to prevent debug statements in production code
- **Best Practices**: Added documentation for proper debugging and logging practices

**ReviewsLive Module Cleanup**
The `ReviewsLive` module has been cleaned up to remove unused code:

- **Removed Unused Constants**: Eliminated the `@valid_filter_types` module attribute that was not being used in the implementation
- **Streamlined Code**: Filter type validation is handled directly in the `parse_filter_type/1` function, making the code more maintainable
- **Improved Readability**: Cleaner module structure with better separation of concerns

**MainNavigation Component Formatting**
The `MainNavigation` component has been improved with better code formatting:

- **Enhanced Readability**: Improved line breaks and indentation for better code organization
- **Attribute Formatting**: Better formatting of component attributes with proper line breaks and documentation
- **Code Structure**: Cleaner HTML comment formatting and consistent indentation throughout
- **Maintainability**: More readable code structure that follows Elixir and Phoenix formatting conventions

### Authentication System Improvements

**Enhanced Async Result Handling (AuthLive)**
The authentication system has been improved with more robust async result processing:

- **Flexible Response Format Support**: The `handle_async/3` functions now handle both direct results (`{:ok, result}`) and nested tuple results (`{:ok, {:ok, result}}`)
- **Improved Error Handling**: Enhanced error processing that gracefully handles both direct errors (`{:error, reason}`) and nested error tuples (`{:ok, {:error, reason}}`)
- **Better Compatibility**: More resilient to different response formats from the Auth context, improving reliability across different async operation patterns
- **Future-Proof Design**: Better prepared for API changes and different async operation patterns

These improvements ensure the authentication flow remains stable and reliable regardless of how the underlying Auth context returns results from async operations.

## Development Guidelines

### Code Quality & Debugging

**Debug Statement Management:**
- Remove all `IO.puts`, `IO.inspect`, and similar debug statements before committing
- Use `Logger.debug/1` for development debugging that can be controlled via configuration
- Leverage `IEx.pry` for interactive debugging during development
- Use proper logging levels (`Logger.info/1`, `Logger.warning/1`, `Logger.error/1`) for production logging

**Code Formatting:**
```bash
# Format all code before committing
mix format

# Check formatting in CI
mix format --check-formatted
```

**Testing:**
```bash
# Run full test suite
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/flixir_web/live/search_live_test.exs
```

## Configuration

### Environment Variables
```bash
# Required
TMDB_API_KEY=your_api_key_here

# Authentication (Optional - defaults provided)
TMDB_BASE_URL=https://api.themoviedb.org/3
TMDB_REDIRECT_URL=http://localhost:4000/auth/callback
TMDB_SESSION_TIMEOUT=86400

# Database & Application (Optional)
DATABASE_URL=postgres://user:pass@localhost/flixir_dev
SECRET_KEY_BASE=your_secret_key_base
PHX_HOST=localhost
```

### TMDB Configuration
Configure in `config/config.exs`:
```elixir
config :flixir, :tmdb,
  api_key: System.get_env("TMDB_API_KEY"),
  base_url: "https://api.themoviedb.org/3",
  timeout: 5_000,
  max_retries: 3

# Authentication-specific configuration
config :flixir, :tmdb_auth,
  api_key: System.get_env("TMDB_API_KEY"),
  base_url: System.get_env("TMDB_BASE_URL") || "https://api.themoviedb.org/3",
  redirect_url: System.get_env("TMDB_REDIRECT_URL") || "http://localhost:4000/auth/callback",
  session_timeout: String.to_integer(System.get_env("TMDB_SESSION_TIMEOUT") || "86400")
```

### Session Management Configuration

The `AuthSession` plug is automatically configured in the router pipelines:

```elixir
# All browser routes include automatic session validation
pipeline :browser do
  # ... other plugs
  plug FlixirWeb.Plugs.AuthSession
end

# Protected routes require authentication
pipeline :authenticated do
  plug :browser
  plug FlixirWeb.Plugs.AuthSession, require_auth: true
end
```

**Session Storage:**
- Session IDs are stored in secure, HTTP-only cookies using Phoenix's session configuration
- Session data is persisted in the `auth_sessions` database table
- Automatic cleanup of expired sessions with database maintenance
- Fresh user data retrieved from TMDB API on each request validation
- Configurable redirect paths for authentication requirements

**Phoenix Session Configuration:**
```elixir
# config/config.exs - Development defaults
config :flixir, FlixirWeb.Endpoint,
  session: [
    store: :cookie,
    key: "_flixir_key",
    signing_salt: "session_salt_key_change_in_prod",
    encryption_salt: "session_encrypt_salt_change_in_prod",
    max_age: 86400,  # 24 hours
    secure: false,   # Will be overridden in prod
    http_only: true,
    same_site: "Lax"
  ]

# config/runtime.exs - Production overrides
config :flixir, FlixirWeb.Endpoint,
  session: [
    secure: true,        # Require HTTPS in production
    http_only: true,     # Prevent XSS access to cookies
    same_site: "Strict", # Enhanced CSRF protection
    max_age: String.to_integer(System.get_env("SESSION_MAX_AGE") || "86400")
  ]
```

### Database Schema

The application includes the following database tables:

#### Authentication Sessions (`auth_sessions`)
```sql
CREATE TABLE auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_session_id VARCHAR(255) NOT NULL UNIQUE,
  tmdb_user_id INTEGER NOT NULL,
  username VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  last_accessed_at TIMESTAMP WITH TIME ZONE NOT NULL,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE UNIQUE INDEX idx_auth_sessions_tmdb_session_id ON auth_sessions(tmdb_session_id);
CREATE INDEX idx_auth_sessions_expires_at ON auth_sessions(expires_at);
CREATE INDEX idx_auth_sessions_tmdb_user_id ON auth_sessions(tmdb_user_id);
```

This table stores user authentication sessions with:
- **UUID Primary Key**: Secure session identification
- **TMDB Integration**: Links to TMDB user accounts and sessions
- **Expiration Management**: Automatic session cleanup based on timestamps
- **Performance Indexes**: Optimized queries for session validation and cleanup

**Migration**: The table is created by the `20250725214604_create_auth_sessions.exs` migration, which includes:
- Primary table creation with proper field types and constraints
- Unique index on `tmdb_session_id` for fast session lookups
- Index on `expires_at` for efficient cleanup operations
- Index on `tmdb_user_id` for user-specific session queries

## Testing

Run the full test suite:
```bash
mix test
```

Run tests with coverage:
```bash
mix test --cover
```

The application includes comprehensive test coverage for:
- **Unit Tests**: All contexts, modules, and business logic components
- **Component Tests**: UI components including navigation, movie lists, reviews, and search
- **LiveView Tests**: Real-time interactions and state management
- **Integration Tests**: Complete user workflows and end-to-end scenarios
- **Authentication Tests**: TMDB authentication flow, session management, and security
- **Navigation Tests**: Main navigation component with authentication state handling
- **Performance Tests**: Load testing, concurrent usage, and caching behavior
- **Error Handling**: Comprehensive error scenarios and recovery mechanisms
- **Mock Testing**: External API dependencies with reliable test data
- **Security Testing**: Authentication flows, session handling, and data protection

### Component Test Coverage

**Navigation Component Testing (`test/flixir_web/components/main_navigation_test.exs`):**
The main navigation component includes comprehensive test coverage for:
- **Authentication States**: Testing both authenticated and unauthenticated navigation states
- **User Menu Functionality**: User menu rendering with username display and logout options
- **Login Button Display**: Proper login button rendering for unauthenticated users
- **Active Section Highlighting**: Visual indicators for current navigation section
- **Component Integration**: Seamless integration with authentication system

**Test Scenarios:**
- Navigation rendering with login button when user is not authenticated
- Navigation rendering with user menu when user is authenticated
- Current section highlighting with proper CSS classes
- User menu display with username and full name handling
- Login button functionality and correct routing

### Integration Test Suite

The application features a comprehensive integration test suite (`test/flixir_web/integration/movie_lists_test.exs`) that provides end-to-end testing for the movie lists feature:

**End-to-End Workflow Testing:**
- Complete navigation workflows between different list types (popular, trending, top-rated, upcoming, now-playing)
- Pagination workflows with load more functionality and URL parameter handling
- Direct URL navigation with parameters and state preservation
- Movie card navigation with list context preservation

**Caching Behavior Integration:**
- Cache hit vs cache miss performance testing and behavior verification
- Cache behavior across different list types with state management
- Cache performance under concurrent load with multiple simulated users
- Memory usage monitoring during extended navigation sessions

**Error Scenarios and Recovery:**
- Timeout error handling with automatic retry mechanisms
- Rate limiting error handling with appropriate user feedback
- Network error handling and recovery workflows
- API error handling for various failure scenarios
- Unauthorized error handling with proper messaging
- Error recovery across list type switches with state management

**Performance Integration Tests:**
- List switching performance benchmarks with timing requirements
- Pagination performance testing with increasing delays simulation
- Memory usage stability monitoring during extended navigation
- Concurrent user load testing with success rate validation

**Test Features:**
- **Realistic Data**: Uses comprehensive mock API responses that mirror production data structures
- **Performance Monitoring**: Includes timing benchmarks and memory usage tracking
- **Concurrent Testing**: Simulates multiple users accessing the system simultaneously
- **Error Simulation**: Tests various failure scenarios with proper recovery mechanisms
- **State Management**: Verifies proper state transitions and URL parameter handling
- **Cache Integration**: Tests actual caching behavior with Agent-based cache state simulation

**Helper Functions:**
- `transform_api_response/1`: Converts mock API responses to SearchResult structs
- `parse_date/1`: Handles date parsing with proper error handling
- `format_response/3`: Formats responses for different return format requirements

The integration tests ensure that all components work together seamlessly and provide confidence in the system's reliability under various conditions.

### Test Architecture

The test suite uses comprehensive mocking strategies to ensure reliable and fast tests:

**Auth Context Testing:**
- **TMDBClient Testing**: Comprehensive tests for all authentication API operations
  - `create_request_token/0` tests with success and failure scenarios
  - `create_session/1` tests with valid and invalid tokens
  - `delete_session/1` tests for proper session cleanup
  - `get_account_details/1` tests for user data retrieval
  - Error handling tests for all HTTP status codes and network failures
  - Request/response parsing tests with various API response formats
  - Configuration tests for API key validation and timeout settings
- **Auth Context Integration**: Full authentication flow testing with proper logging verification
  - `start_authentication/0` tests with token creation and URL building
  - `complete_authentication/1` tests with session creation and user account integration
  - `validate_session/1` tests with session validation and last access updates
  - `logout/1` tests with proper TMDB session cleanup and local session deletion
  - `get_current_user/1` tests with fresh user data retrieval from TMDB
- **AuthSession Plug Testing**: Comprehensive middleware testing for session management (`test/flixir_web/plugs/auth_session_test.exs`)
  - Session validation tests with valid, expired, and invalid sessions
  - User context injection tests with proper conn assign verification
  - Authentication requirement tests with redirect behavior and custom paths
  - Helper function tests for session storage, retrieval, and redirect handling
  - Security tests for session cleanup and cookie handling
  - Error handling tests for authentication failures and recovery
  - Edge case testing for malformed session data and Auth context errors
- Authentication flow tests with comprehensive TMDB API mocking
- Session management tests including creation, validation, and expiration
- Security tests for session encryption and cookie handling
- Authentication error handling and recovery mechanism testing
- Session cleanup and background job testing
- User context integration tests across LiveView components
- Logging verification tests for authentication events and error tracking

**Media Context Testing:**
- TMDB Client tests include comprehensive mocking of API responses for all endpoints
- Movie list functions (`get_popular_movies`, `get_trending_movies`, `get_top_rated_movies`, `get_upcoming_movies`, `get_now_playing_movies`) are fully tested with extensive scenarios:
  - API response handling and data transformation
  - Caching behavior with 15-minute TTL verification
  - Pagination support and `has_more` logic
  - Return format compatibility (list vs map formats)
  - Error handling for timeouts, rate limiting, authentication, and network failures
  - Edge cases like empty results, malformed data, and missing pagination info
  - Cache format conversion between legacy list format and new map format
- Search functionality tests cover pagination, filtering, and error scenarios
- Cache integration tests verify hit/miss scenarios and TTL behavior

**Reviews Context Testing:**
- All Reviews context functions are properly mocked in LiveView tests
- `filter_reviews/2` function is mocked to test filtering behavior without dependencies
- `get_reviews/3`, `get_rating_stats/2`, and other context functions have dedicated mocks
- Test mocks simulate real filtering, sorting, and pagination logic for accurate behavior testing

**Component Testing:**
- Movie list components are comprehensively tested with various data states, user interactions, loading states, error states, empty states, responsive behavior, and accessibility features
- Review components include tests for expandable content, spoiler warnings, and filtering
- Search components verify real-time search behavior and result display

**LiveView Integration Tests:**
- MovieDetailsLive tests include complete mocking of the Reviews context
- MovieListsLive tests verify list navigation, pagination, and error handling with comprehensive coverage:
  - Mount behavior and initial state management
  - URL parameter handling for list types and pagination
  - List switching with proper state transitions
  - Load more functionality with movie appending
  - Error recovery workflows with retry mechanisms
  - Complete user workflows from browsing to pagination
  - Navigation state preservation and URL generation
  - Data handling for both legacy and new API response formats
- SearchLive tests cover comprehensive search workflows with filtering and sorting
- Tests verify proper integration between LiveView and context layers
- Mock functions return realistic data structures matching production behavior

**Comprehensive Integration Testing:**
- **End-to-End Workflows**: Full user journey testing from initial page load through navigation, pagination, and error recovery
- **Multi-Component Integration**: Tests verify seamless interaction between LiveView, Media context, TMDB client, and cache layers
- **Performance Benchmarking**: Integration tests include performance requirements and timing validations
- **Concurrent User Simulation**: Tests system behavior under concurrent load with multiple simulated users
- **Cache Integration Testing**: Verifies actual caching behavior with realistic cache state management
- **Error Recovery Testing**: Comprehensive error scenario testing with proper recovery mechanisms
- **Memory Stability Testing**: Long-running tests monitor memory usage patterns during extended navigation
- **Real-World Scenarios**: Tests simulate actual user behavior patterns and edge cases

**API Client Testing:**
- TMDB Client tests use structured mock responses for consistent testing
- Error handling tests cover timeout, rate limiting, authentication, and network failures
- Movie list endpoint tests verify correct URL construction and parameter handling
- Integration tests can be run with real API keys when available (tagged with `:integration`)

## Development

### Code Quality
```bash
# Format code
mix format

# Check formatting
mix format --check-formatted
```

### Database Operations
```bash
# Reset database (includes auth_sessions table)
mix ecto.reset

# Create migration
mix ecto.gen.migration migration_name

# Run migrations (includes authentication system)
mix ecto.migrate

# Check migration status
mix ecto.migrations
```

### Asset Management
```bash
# Build assets for development
mix assets.build

# Build and minify for production
mix assets.deploy
```

## Deployment

Ready to run in production? Please check the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

### Production Configuration
Ensure the following environment variables are set:
- `TMDB_API_KEY` - Required for TMDB API access
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix session encryption key
- `PHX_HOST` - Production hostname
- `TMDB_REDIRECT_URL` - Production callback URL for authentication (e.g., `https://yourapp.com/auth/callback`)
- `TMDB_SESSION_TIMEOUT` - Session timeout in seconds (default: 86400 = 24 hours)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests (including authentication tests if applicable)
4. Run the test suite (includes authentication system tests)
5. Ensure database migrations are properly tested
6. Submit a pull request

### Authentication Development Notes
- The authentication system uses TMDB's session-based authentication
- The `TMDBClient` module provides a complete HTTP client for TMDB authentication operations
- All authentication requests include proper error handling and retry mechanisms
- Session tokens are validated and managed through secure database storage
- The client supports configurable timeouts and retry policies for production reliability
- Authentication errors are properly categorized and handled with user-friendly messages

**Module Structure:**
- **Request Handling**: Uses the `Req` HTTP client with proper headers and configuration
- **Response Parsing**: Dedicated parsing functions for each API response type
- **Error Classification**: Comprehensive error handling with specific error types
- **Security**: Input validation and secure parameter handling
- **Logging**: Structured logging for debugging and monitoring
- **Configuration**: Flexible configuration through application environment

### TMDB Authentication Client API
The `Flixir.Auth.TMDBClient` module provides the following functions:

```elixir
# Create a new request token (Step 1 of authentication)
{:ok, %{request_token: token, expires_at: datetime}} = TMDBClient.create_request_token()

# Create session from approved token (Step 3 of authentication)
{:ok, %{session_id: session_id}} = TMDBClient.create_session(approved_token)

# Get user account details
{:ok, account_data} = TMDBClient.get_account_details(session_id)

# Delete/invalidate session
{:ok, %{success: true}} = TMDBClient.delete_session(session_id)
```

**Error Handling:**
The client handles various error scenarios:
- `:unauthorized` - Invalid API key or session
- `:not_found` - Resource not found
- `:rate_limited` - API rate limit exceeded
- `:timeout` - Request timeout
- `{:transport_error, reason}` - Network connectivity issues
- `:token_creation_failed` - Token request failed
- `:session_creation_failed` - Session creation failed
- `:session_deletion_failed` - Session deletion failed
- `:invalid_response_format` - Malformed API response

**Configuration:**
The client uses the same TMDB configuration as other modules:
```elixir
config :flixir, :tmdb,
  api_key: System.get_env("TMDB_API_KEY"),
  timeout: 5_000,
  max_retries: 3
```ation-related code should follow security best practices
- Session data is encrypted and stored securely in the database
- Authentication tests should mock TMDB API responses appropriately

## Learn More

### Phoenix Framework
* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

### TMDB API
* Documentation: https://developers.themoviedb.org/3
* API Reference: https://developers.themoviedb.org/3/getting-started

### Kiro Development Tool
* Blog: https://kiro.dev/blog/introducing-kiro/
