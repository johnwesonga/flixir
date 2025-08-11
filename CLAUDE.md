# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Setup and Development
- `mix setup` - Install dependencies and set up the project (equivalent to deps.get, ecto.setup, assets.setup, assets.build)
- `mix phx.server` - Start the Phoenix server
- `iex -S mix phx.server` - Start the server in interactive Elixir shell

### Database Operations
- `mix ecto.create` - Create the database
- `mix ecto.migrate` - Run database migrations
- `mix ecto.reset` - Drop and recreate the database
- `mix ecto.setup` - Create database, run migrations, and seed data

### Testing
- `mix test` - Run all tests (includes database setup)
- `mix test test/path/to/specific_test.exs` - Run a specific test file
- `mix test test/path/to/specific_test.exs:line_number` - Run a specific test

### Code Quality
- `mix format` - Format all Elixir code
- `mix format --check-formatted` - Check if code is properly formatted
- Remove debug statements (`IO.puts`, `IO.inspect`) before committing
- Use `Logger.debug/1` for development debugging instead of `IO.puts`

### Asset Management
- `mix assets.build` - Build CSS and JavaScript assets
- `mix assets.deploy` - Build and minify assets for production

## Architecture Overview

### Core Application Structure
This is a Phoenix LiveView application called **Flixir** that provides search functionality for movies and TV shows using the TMDB (The Movie Database) API.

### Key Components

**Media Context (`lib/flixir/media.ex`)**
- Central business logic for content search and management
- Orchestrates TMDB API calls, caching, and data transformation
- Handles search parameters, filtering, and sorting
- Provides caching layer for performance optimization

**Lists Context (`lib/flixir/lists.ex`)**
- Manages TMDB-native movie lists and collections with comprehensive validation
- Provides full CRUD operations for TMDB movie lists with user authorization and cross-platform sync
- Handles movie addition/removal from TMDB lists with duplicate prevention and error handling
- Implements privacy controls for public/private TMDB lists with access control
- Integrates with TMDB user authentication for secure session management and data isolation
- Supports TMDB list statistics and user collection analytics with sync status monitoring
- Includes comprehensive error handling with user-friendly messages and retry logic
- Features proper logging for debugging and monitoring of TMDB operations
- Provides offline support through queue system with automatic retry and exponential backoff
- Implements optimistic updates with automatic rollback on API failures for seamless UX

**Lists TMDB Client (`lib/flixir/lists/tmdb_client.ex`)**
- HTTP client for TMDB Lists API operations with comprehensive error handling
- **List Management**: Create, read, update, and delete lists on TMDB with full validation
- **Movie Operations**: Add and remove movies from TMDB lists with duplicate prevention
- **Account Integration**: Retrieve all lists for a TMDB account with proper authentication
- **Error Classification**: Intelligent error handling with retry logic and exponential backoff
- **Response Parsing**: Comprehensive response parsing with validation and error detection
- **Security Features**: Secure session handling with URL sanitization for logging
- **Retry Logic**: Automatic retry for transient failures with configurable backoff strategies
- **Comprehensive Logging**: Detailed logging for all operations, errors, and retry attempts
- **Rate Limit Handling**: Graceful handling of TMDB API rate limits with appropriate delays

**Lists Cache (`lib/flixir/lists/cache.ex`)**
- High-performance ETS-based caching system for TMDB list data with GenServer supervision
- **User Lists Caching**: Cache user's complete list collections with automatic expiration (1-hour default TTL)
- **Individual List Caching**: Cache specific list metadata and details for fast access
- **List Items Caching**: Cache movie items within lists to reduce API calls for list contents
- **Cache Management**: Comprehensive cache operations including invalidation, warming, and statistics
- **Automatic Cleanup**: Background process removes expired entries every 5 minutes
- **Performance Monitoring**: Real-time cache statistics including hits, misses, writes, and memory usage
- **Cache Invalidation**: Targeted invalidation for users and specific lists to maintain data consistency
- **Memory Optimization**: ETS tables with read concurrency for high-performance concurrent access
- **Debugging Support**: Comprehensive logging for cache operations and performance monitoring

**Lists Queue System (`lib/flixir/lists/queue.ex`)**
- Offline support and reliable operation processing for TMDB list operations
- **Operation Queuing**: Queue operations when TMDB API is unavailable with comprehensive validation
- **Background Processing**: QueueProcessor GenServer automatically processes pending operations
- **Retry Logic**: Exponential backoff retry mechanism (30s, 60s, 120s, 240s, 480s) for failed operations
- **Status Tracking**: Real-time monitoring of operation status (pending, processing, completed, failed, cancelled)
- **Deduplication**: Prevents duplicate operations for the same user/list/movie combinations
- **Manual Control**: Ability to manually retry failed operations or cancel pending ones
- **Database Schema**: Uses `queued_list_operations` table with optimized indexes for queue processing
- **Operation Types**: Supports create_list, update_list, delete_list, clear_list, add_movie, remove_movie
- **Monitoring**: Comprehensive statistics and operation tracking for queue health
- **Cleanup**: Automatic cleanup of old completed/cancelled operations

**User Movie List Components (`lib/flixir_web/components/user_movie_list_components.ex`)**
- Comprehensive UI component library for TMDB movie list management
- **Container Components**: Main layout with `user_lists_container/1` and responsive `lists_grid/1` with sync status indicators
- **Display Components**: Rich `list_card/1` components showing TMDB list details, movie counts, privacy status, and sync indicators
- **Interactive Forms**: Validated `list_form/1` for creating and editing TMDB lists with privacy controls and validation
- **Modal Components**: Confirmation dialogs for safe deletion (`delete_confirmation_modal/1`), list clearing (`clear_confirmation_modal/1`), movie addition (`add_to_list_selector/1`), and share functionality
- **Sync Status Components**: Real-time sync status indicators showing TMDB synchronization state (synced, syncing, offline, error)
- **State Management**: Loading states with skeleton animations, empty states with call-to-action buttons, error states with retry functionality, and queue status displays
- **Accessibility Features**: Proper ARIA labels, semantic HTML, keyboard navigation, and screen reader support
- **Responsive Design**: Mobile-first design with Tailwind CSS responsive utilities
- **Internationalization**: Support for multiple languages with proper pluralization using `ngettext`
- **Testing Support**: Comprehensive `data-testid` attributes for reliable component testing

**User Movie List LiveView (`lib/flixir_web/live/user_movie_list_live.ex`)**
- Complete LiveView implementation for managing individual TMDB movie lists with comprehensive functionality
- **TMDB-Native Integration**: Direct integration with TMDB Lists API for real-time synchronization across platforms
- **Authentication Integration**: Automatic authentication checks with redirect handling for unauthenticated users
- **List Management Interface**: Full CRUD operations for TMDB movie lists with real-time updates and sync status
  - **Edit Lists**: In-place editing with dynamic form management, validation feedback, and TMDB sync
  - **Privacy Controls**: Toggle between public and private lists with optimistic updates and TMDB synchronization
  - **Share Functionality**: Generate and copy TMDB share URLs for public lists with native TMDB integration
- **Movie Management**: Comprehensive movie operations with TMDB API integration
  - **Add Movies**: Add movies to TMDB lists with duplicate prevention and optimistic updates
  - **Remove Movies**: Remove movies with confirmation modals and automatic rollback on failures
  - **Movie Display**: Rich movie cards with TMDB data and loading states
- **Sync Status Management**: Real-time synchronization status with TMDB
  - **Status Indicators**: Visual indicators for synced, syncing, offline, and error states
  - **Force Sync**: Manual synchronization with TMDB API for data consistency
  - **Queue Integration**: Display and manage queued operations for offline support
- **Optimistic Updates**: Immediate UI updates with automatic rollback on API failures for seamless UX
- **Offline Support**: Queue operations when TMDB API is unavailable with automatic retry and exponential backoff
- **Form State Management**: Comprehensive form handling with validation, error display, and state persistence
- **Modal Operations**: Safe destructive operations with detailed confirmation dialogs
  - **Remove Confirmation**: Shows movie details before removal from TMDB list
  - **Share Modal**: Display TMDB share URLs with copy-to-clipboard functionality
  - **Add Movie Modal**: Interface for adding movies by TMDB ID with validation
- **Error Handling**: Comprehensive error handling with retry mechanisms, user feedback, and TMDB-specific error messages
- **Loading States**: Smooth loading indicators during TMDB operations with proper state management
- **User Authorization**: Ensures users can only access and modify their own TMDB lists with proper security
- **Background Operations**: Asynchronous TMDB API operations with proper error handling and state updates
- **Statistics Integration**: Real-time display of TMDB list statistics and sync status
- **Component Integration**: Seamless integration with UserMovieListComponents for consistent UI
- **Template Structure**: Clean HEEx template with TMDB-specific features and modal overlays

**Auth Context (`lib/flixir/auth.ex`)**
- Manages user authentication and session handling
- Integrates with TMDB's session-based authentication system through TMDBClient
- Provides secure session storage and validation with comprehensive logging
- Handles user account management and session cleanup
- Implements complete authentication flow with proper error handling and logging
- Includes session validation, user data retrieval, and secure logout functionality

**Auth Error Handler (`lib/flixir/auth/error_handler.ex`)**
- Comprehensive error handling for TMDB authentication operations
- Classifies errors into user-friendly categories (network, rate limiting, authentication failures, etc.)
- Implements retry logic with exponential backoff and jitter
- Provides both user-friendly and technical error messages
- Includes telemetry support for monitoring authentication issues
- Handles fallback strategies for different error types

**Auth Session Plug (`lib/flixir_web/plugs/auth_session.ex`)**
- Middleware for automatic session validation and user context injection
- Validates TMDB session IDs from cookies against the database on every request
- Injects current user data and authentication status into conn assigns
- Handles expired session cleanup and authentication requirements
- Provides helper functions for session management (put/clear session ID, redirect handling)
- Supports both optional and required authentication with configurable redirect behavior
- Comprehensive logging for authentication events and security monitoring

**Auth Live View (`lib/flixir_web/live/auth_live.ex`)**
- Complete user authentication interface for TMDB integration
- Handles login initiation, callback processing, and logout confirmation
- Implements async authentication operations using Phoenix async assigns with enhanced result handling
- Robust async result processing that supports both direct and nested response formats for improved reliability
- Manages authentication state with loading indicators and error messages
- Integrates seamlessly with AuthSession plug for session management
- Provides comprehensive error handling with user-friendly messages
- Supports authentication flow routes: /auth/login, /auth/callback, /auth/logout
- Preserves navigation context and handles post-login redirects

**Auth Hooks (`lib/flixir_web/live/auth_hooks.ex`)**
- LiveView on_mount callback for centralized authentication state management
- Transfers authentication state from HTTP connection to LiveView socket
- Enhanced debugging capabilities for troubleshooting authentication issues
- Validates session consistency between Phoenix sessions and socket assigns
- Provides comprehensive logging for authentication state debugging
- Detects potential issues with AuthSession plug integration
- Ensures authentication context is available in all LiveView components
- **Centralized Architecture**: Eliminates need for manual authentication handling in individual LiveViews
- **DRY Principle**: Removes duplicate authentication code across LiveView modules
- **Consistency**: Ensures uniform authentication state structure across all components

**Search Live View (`lib/flixir_web/live/search_live.ex`)**
- Real-time search interface with debounced input (300ms)
- Handles URL parameters for shareable search links
- Manages search state including pagination, filtering, and sorting
- Implements comprehensive error handling and validation
- **Authentication Integration**: Uses centralized `on_mount` hook pattern for authentication state management
- **Clean Architecture**: Removed manual authentication state handling in favor of `AuthHooks` module

**Main Navigation Component (`lib/flixir_web/components/main_navigation.ex`)**
- Unified navigation system across search, movies, reviews, and user lists sections
- Authentication-aware navigation with dynamic user menu or login button
- Active state management with visual indicators for current section
- Responsive design with mobile-friendly touch targets
- Comprehensive test coverage for authentication states and user interactions
- Seamless integration with AuthSession plug for automatic state management
- **User Lists Integration**: Direct access to personal movie lists for authenticated users

**TMDB Client (`lib/flixir/media/tmdb_client.ex`)**
- HTTP client for TMDB API interactions
- Handles authentication, rate limiting, and error responses
- Provides movie and TV show search and details endpoints

**Auth TMDB Client (`lib/flixir/auth/tmdb_client.ex`)**
- Specialized HTTP client for TMDB authentication operations
- Implements three-step TMDB authentication flow (token → approval → session)
- Handles request token creation, session management, and user account details
- Provides secure session deletion and comprehensive error handling
- Includes retry logic with exponential backoff for network resilience
- Integrated with Auth context for seamless authentication flow management

**Lists TMDB Client (`lib/flixir/lists/tmdb_client.ex`)**
- HTTP client for TMDB Lists API operations with comprehensive error handling
- **List Management**: Create, read, update, and delete lists on TMDB with full validation
- **Movie Operations**: Add and remove movies from TMDB lists with duplicate prevention
- **Account Integration**: Retrieve all lists for a TMDB account with proper authentication
- **Error Classification**: Intelligent error handling with retry logic and exponential backoff
- **Response Parsing**: Comprehensive response parsing with validation and error detection
- **Security Features**: Secure session handling with URL sanitization for logging
- **Retry Logic**: Automatic retry for transient failures with configurable backoff strategies
- **Comprehensive Logging**: Detailed logging for all operations, errors, and retry attempts
- **Rate Limit Handling**: Graceful handling of TMDB API rate limits with appropriate delays

**Caching System**
- **Media Cache (`lib/flixir/media/cache.ex`)**: In-memory caching for search results and content details with configurable TTL (5 minutes for search, 30 minutes for details)
- **Lists Cache (`lib/flixir/lists/cache.ex`)**: High-performance ETS-based caching for TMDB list data including user lists, individual lists, and list items with 1-hour default TTL and automatic expiration cleanup
- Provides cache statistics, monitoring, and management functions for both caching layers

### Data Flow

**Search Flow:**
1. User input → SearchLive (debounced validation)
2. SearchLive → Media context (search orchestration)
3. Media → Cache (check for cached results)
4. Cache miss → TMDB Client (API call)
5. TMDB Client → Media (transform and cache response)
6. Media → SearchLive (display results)

**Authentication Flow:**
1. User login → AuthLive (initiate TMDB authentication)
2. AuthLive → Auth context → TMDB API (create request token)
3. User redirect → TMDB website (approve application access)
4. TMDB callback → AuthLive (process approved token)
5. AuthLive → Auth context → TMDB API (create session from token)
6. AuthLive → AuthSession plug (store session ID in cookie)
7. Every request → AuthSession plug (session validation)
8. AuthSession → Auth context (validate session against database)
9. Auth context → TMDB API (get fresh user data for valid sessions)
10. AuthSession → conn assigns (inject user context: current_user, current_session, authenticated?)
11. LiveView/Controller → access user data from conn assigns
12. Optional: Redirect to login if authentication required and user not authenticated

**Lists Flow:**
1. User action → UserMovieListsLive (create/edit/delete list or add/remove movie)
2. UserMovieListsLive → Lists context (validate user authorization)
3. Lists context → Lists Cache (check for cached list data)
4. Cache miss → Lists TMDB Client (TMDB API operations for list management)
5. Lists TMDB Client → TMDB Lists API (create/update/delete lists, add/remove movies)
6. **Success Path**: Lists context → Lists Cache (cache updated list data with TTL)
7. **Failure Path**: Lists context → Queue System (enqueue failed operations for retry)
8. Lists context → Database (local CRUD operations with constraints for caching/sync)
9. Lists context → Media context (fetch TMDB movie data when needed)
10. Media context → TMDB API (get movie details for display)
11. Lists context → UserMovieListsLive (return results with error handling)
12. UserMovieListsLive → User (display updated lists with feedback messages and real-time updates)
13. Cache invalidation → Lists Cache (invalidate affected cache entries on updates)
14. **Background Processing**: QueueProcessor → Queue System (process pending operations with retry logic)

**Recent Authentication Improvements:**
- Enhanced async result handling in AuthLive with support for both direct results (`{:ok, result}`) and nested tuple results (`{:ok, {:ok, result}}`)
- Improved error handling that gracefully processes both direct errors (`{:error, reason}`) and nested error tuples (`{:ok, {:error, reason}}`)
- More robust authentication flow that handles various response formats from the Auth context
- Better compatibility with different async operation patterns and future API changes

**Authentication Debugging:**
The authentication system includes comprehensive debugging support for troubleshooting issues:

- **AuthHooks Debugging**: Enhanced logging in the `on_mount` callback to track authentication state transfer
- **Session Validation**: Logs session keys and authentication state during LiveView mounting
- **State Mismatch Detection**: Identifies when session IDs exist but authentication state is false
- **Plug Integration Monitoring**: Detects potential issues with AuthSession plug integration
- **Development Logging**: Both Logger and IO.puts output for immediate debugging feedback
- **Session Consistency Checks**: Validates that Phoenix sessions and socket assigns are properly synchronized

**Debugging Output Examples:**
```
=== AuthHooks on_mount - socket.assigns keys: [:authenticated?, :current_user, :current_session] ===
=== AuthHooks on_mount - session keys: ["tmdb_session_id", "_csrf_token"] ===
=== AuthHooks on_mount - authenticated?: true, current_user: %{"id" => 123, "username" => "user"} ===
=== AuthHooks: Found session ID but authenticated? is false - possible plug issue ===
```

This debugging information helps identify authentication flow issues during development and ensures proper session management across the application.

### Key Features
- **Debounced Search**: 300ms delay to reduce API calls
- **Pagination**: 20 results per page with lazy loading
- **Filtering**: By content type (movies, TV shows, both)
- **Sorting**: By relevance, popularity, release date, or title
- **Caching**: Optimized API usage with intelligent cache management
- **Error Handling**: Comprehensive error states and recovery
- **Authentication**: TMDB-based user authentication with automatic session management
- **Session Management**: Transparent session validation and user context injection across all requests
- **Security**: Secure session storage with configurable encryption salts, automatic cleanup, and comprehensive logging
- **TMDB Lists Integration**: Native TMDB Lists API integration with comprehensive error handling and retry logic
- **User Movie Lists**: Personal movie collections with privacy controls
  - Create, edit, and delete custom movie lists with comprehensive validation
  - Add and remove movies from lists with duplicate prevention and error handling
  - Public and private list visibility settings with user authorization
  - List statistics and user collection analytics
  - Seamless integration with TMDB user authentication and session management
  - Comprehensive error handling with user-friendly messages
  - Proper logging for debugging and monitoring
  - Rich UI component library with responsive design and accessibility features
  - Modal-based interactions for safe destructive operations
  - Skeleton loading states and smooth transitions for better UX
  - **User Lists Dashboard**: Complete LiveView interface for managing all user movie lists
    - Real-time list management with live updates
    - Authentication-protected access with automatic redirects
    - Form-based list creation and editing with validation
    - Confirmation modals for safe destructive operations
    - Statistics display and user collection analytics
    - Comprehensive error handling with retry mechanisms

### Configuration
- Database: PostgreSQL with Ecto
- HTTP Client: Req library for TMDB API calls (including dedicated Lists API client)
- Frontend: Phoenix LiveView with Tailwind CSS
- Server: Bandit adapter
- Session Management: Phoenix cookie-based sessions with configurable security settings
- TMDB Lists API: Comprehensive client with retry logic, exponential backoff, and error classification

### Development Notes
- Uses Phoenix 1.8 with LiveView for real-time interactions
- Built with Kiro framework principles
- Comprehensive test coverage including integration, performance, and error handling tests
- Mock-based testing for external API dependencies

### Component Development Patterns

**Component Structure:**
- All UI components are organized by feature in `lib/flixir_web/components/`
- Each component module includes comprehensive documentation with examples
- Components use `attr` declarations for type safety and documentation
- All components include `data-testid` attributes for reliable testing

**Component Usage in LiveViews:**
```elixir
# Import component modules
import FlixirWeb.UserMovieListComponents

# Use components in templates
<.user_lists_container
  lists={@user_lists}
  loading={@loading}
  error={@error}
  current_user={@current_user}
/>

<.list_form
  :if={@show_form}
  form={@form}
  action={@form_action}
  title="Create New List"
/>
```

**Component Testing Patterns:**
```elixir
# Component tests use Phoenix.LiveViewTest
import Phoenix.LiveViewTest
import FlixirWeb.UserMovieListComponents

test "renders component with data" do
  html = render_component(&list_card/1, %{list: sample_list()})
  assert html =~ "expected content"
  assert html =~ "data-testid=\"list-card\""
end
```

**Accessibility and Responsive Design:**
- All components include proper ARIA labels and semantic HTML
- Mobile-first responsive design using Tailwind CSS utilities
- Keyboard navigation support for interactive elements
- Screen reader compatibility with descriptive text and labels
- High contrast color schemes for better visibility

### Recent Technical Improvements
- **Enhanced Authentication Async Handling**: Improved `handle_async/3` functions in AuthLive to support both direct and nested tuple response formats
- **Robust Error Processing**: Better error handling that works with various async operation result patterns
- **Future-Proof Design**: More resilient authentication flow that adapts to different Auth context response formats
- **Comprehensive Integration Testing**: Added complete authentication flow integration tests covering end-to-end workflows

### Authentication Flow Integration Testing

The application includes comprehensive integration testing for the complete TMDB authentication system in `test/flixir_web/integration/auth_flow_test.exs`:

**Complete Authentication Flow Tests:**
- **Successful Login Flow**: End-to-end testing from login initiation to authenticated session
  - Login page rendering and user interaction
  - TMDB API token creation and external redirect handling
  - Authentication callback processing with approved tokens
  - Session storage in both database and encrypted cookies
  - User authentication state validation across subsequent requests
- **Successful Logout Flow**: Complete logout process verification
  - Logout confirmation page and user interaction
  - TMDB session deletion and local session cleanup
  - Cookie clearing and authentication state reset
  - Post-logout redirect handling and flash message display
- **Protected Route Redirect**: Authentication-required route handling
  - Unauthenticated access attempts to protected routes
  - Redirect path storage and post-login navigation preservation
  - Session storage with preserved redirect destinations

**Error Handling Integration Tests:**
- **Token Creation Failures**: TMDB API token creation error handling
- **Session Creation Failures**: Invalid or expired token error processing
- **User Authentication Denial**: User cancellation of TMDB authentication
- **Invalid Callback Parameters**: Malformed or missing callback data handling
- **Network Error Recovery**: Network failure scenarios and user feedback

**Session Management Integration Tests:**
- **Expired Session Cleanup**: Automatic cleanup of expired sessions
- **Session Activity Tracking**: Last accessed time updates and validation
- **Invalid Session Handling**: Cleanup of non-existent or corrupted sessions

**Security Integration Tests:**
- **CSRF Protection**: CSRF token inclusion and validation in authentication forms
- **Encrypted Session Storage**: Secure session data handling and cookie encryption

**Test Implementation Features:**
- **Mock Integration**: Comprehensive TMDB API mocking for reliable testing
- **Database Integration**: Actual database operations with session lifecycle testing
- **Cookie Management**: Phoenix session handling and encrypted cookie verification
- **Async Operation Testing**: LiveView async operations with proper timing
- **State Verification**: Authentication state validation across multiple request cycles

### Testing Structure
- **Unit Tests**: `test/flixir/media/`, `test/flixir/auth/`, and `test/flixir/lists/` - Test individual components and business logic including queue system operations
- **LiveView Tests**: `test/flixir_web/live/` - Test user interactions and real-time features
- **Component Tests**: `test/flixir_web/components/` - Test UI components including navigation, movie lists, reviews, and search components
- **Integration Tests**: `test/flixir_web/integration/` - Test complete workflows including:
  - **Authentication Flow** (`auth_flow_test.exs`): Complete TMDB authentication process testing
  - **Movie Lists** (`movie_lists_test.exs`): Comprehensive movie browsing and pagination workflows
  - **User Lists** (`user_lists_test.exs`): Personal movie list management and operations (planned)
  - **Error Handling**: End-to-end error scenarios and recovery mechanisms
- **Security Tests**: Authentication security, session management, and CSRF protection
- **Performance Tests**: Measure search response times, concurrent usage, and system performance under load

### Environment-Specific Configuration
- Development: Live reloading, debug logging, local mailbox, relaxed security settings
- Test: Quiet database setup, mocked external dependencies, test-specific configurations
- Production: Optimized assets, secure headers, HTTPS enforcement, proper error handling

### Configuration Structure
- **Base Configuration** (`config/config.exs`): Core application settings including LiveView signing salt and session configuration
- **Development** (`config/dev.exs`): Development-specific overrides with relaxed security
- **Production** (`config/prod.exs`): Production optimizations and security settings
- **Runtime** (`config/runtime.exs`): Environment variable-based configuration for deployment with **enabled TMDB authentication by default**
- **Test** (`config/test.exs`): Test environment settings with mocked services

### Configuration Notes
- **LiveView Configuration**: The endpoint includes a `live_view` signing salt for WebSocket security
- **Session Security**: Comprehensive session configuration with encryption, signing, and security headers
- **Environment Variables**: Production uses environment variables for sensitive configuration values
- **Duplicate Prevention**: Ensure configuration keys don't appear multiple times in the same config block