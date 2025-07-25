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
- **Session Management**: Persistent user sessions with automatic expiration handling
- **Secure Storage**: Encrypted session data with proper security measures
- **User Context**: Seamless integration of user authentication across the application
- **Privacy Protection**: GDPR-compliant session handling and data protection

### 🚀 Performance & UX
- **Real-time Updates**: Phoenix LiveView for seamless interactions
- **Responsive Design**: Tailwind CSS for mobile-first design
- **Error Handling**: Graceful error handling with retry mechanisms
- **Loading States**: Smooth loading indicators and transitions
- **Error Recovery**: One-click retry functionality for failed operations

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

2. Configure your TMDB API key in `config/dev.exs`:
   ```elixir
   config :flixir, :tmdb,
     api_key: "your_tmdb_api_key_here"
   ```

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

## Architecture

### Core Modules

#### Auth Context (`lib/flixir/auth/`)
- **Session**: User session management with TMDB integration
- **TMDBClient**: TMDB authentication API client for token and session management
  - `create_request_token/0`: Initiates TMDB authentication flow by creating request tokens
  - `create_session/1`: Converts approved tokens into authenticated sessions
  - `delete_session/1`: Invalidates TMDB sessions for secure logout
  - `get_account_details/1`: Retrieves user account information from TMDB
  - Comprehensive error handling with retry logic and exponential backoff
  - Secure HTTP client configuration with proper timeouts and headers
- **Authentication Flow**: Three-step TMDB authentication (token → approval → session)
- **Security**: Secure session storage with encryption and proper expiration handling
- **Logging**: Comprehensive logging for authentication events, errors, and security monitoring

#### Media Context (`lib/flixir/media/`)
- **SearchResult**: Data structure for search results and movie lists
- **TMDBClient**: API client for The Movie Database with movie list endpoints
- **Cache**: High-performance caching layer with specialized movie list caching
- **Movie Lists**: Five curated movie list functions with caching and error handling

#### Reviews Context (`lib/flixir/reviews/`)
- **Review**: Individual review data structure
- **RatingStats**: Aggregated rating statistics
- **Cache**: Review-specific caching system
- **TMDBClient**: Review-focused API operations

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
- **AuthLive**: User authentication interface with login/logout functionality
  - TMDB authentication flow with secure token handling
  - Session management and user context integration
  - Error handling for authentication failures and recovery
- **SearchLive**: Real-time search interface with filtering and sorting
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

#### Session Management (`lib/flixir_web/plugs/auth_session.ex`)
The `AuthSession` plug provides comprehensive session management and authentication validation:

**Core Functionality:**
- **Session Validation**: Validates TMDB session IDs from cookies against the database
- **User Context Injection**: Automatically injects current user data and session information into conn assigns
- **Automatic Cleanup**: Handles expired sessions with automatic cookie cleanup
- **Authentication Requirements**: Optional authentication enforcement with configurable redirect behavior
- **Security Logging**: Comprehensive logging for authentication events and security monitoring

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
- **Authentication Routes**: 
  - `/auth/login` - User login initiation
  - `/auth/callback` - TMDB authentication callback handling
  - `/auth/logout` - User logout and session cleanup
- **Home Route**: `/` - Landing page with HTTP GET route to SearchLive for immediate search functionality
- **Search Route**: `/search` - Main search interface with LiveView and URL parameter support
- **Movie Lists Routes**: 
  - `/movies` - Popular movies (default list)
  - `/movies/:list_type` - Specific movie lists (trending, top-rated, upcoming, now-playing)
  - URL parameters: `?page=N` for pagination support
- **Detail Routes**: `/:type/:id` - Dynamic LiveView routes for movie and TV show details
- **URL Parameters**: Shareable search states with query, filter, and sort parameters
- **Mixed Navigation**: Combines HTTP GET routes and LiveView for optimal performance and user experience
- **Protected Routes**: Session validation middleware for authenticated-only features using `AuthSession` plug

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
- **Accessibility**: Proper ARIA labels, semantic HTML, keyboard navigation, and test IDs

**Navigation Components:**
- **`main_nav/1`**: Primary navigation bar with search, movies, and reviews sections
- **`sub_nav/1`**: Secondary navigation for subsections within each main section
- **`nav_item/1`**: Private component for individual navigation items with icons, labels, and descriptions

**Component Usage:**
```heex
<!-- Main navigation with current section -->
<.main_nav current_section={:movies} />

<!-- Sub-navigation for movie lists -->
<.sub_nav 
  items={[
    {:popular, "Popular", "/movies", "Most popular movies"},
    {:trending, "Trending", "/movies/trending", "Trending this week"},
    {:top_rated, "Top Rated", "/movies/top-rated", "Highest rated movies"}
  ]}
  current={:popular}
/>
```

**Visual Design:**
- Clean, modern interface with subtle shadows and borders
- Blue accent color for active states and brand elements
- Smooth transitions and hover effects
- Responsive grid layout that adapts to different screen sizes
- Consistent spacing and typography throughout

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

#### Authentication System Implementation
The application implements a comprehensive TMDB-based authentication system with seamless session management:

**Authentication Flow:**
1. **Token Request**: `TMDBClient.create_request_token/0` requests a token from TMDB API
2. **User Authorization**: User is redirected to TMDB to approve the application
3. **Session Creation**: `TMDBClient.create_session/1` exchanges approved token for session ID
4. **Session Storage**: Session data is securely stored in the database with encryption
5. **Account Integration**: `TMDBClient.get_account_details/1` retrieves user profile information
6. **Session Management**: `TMDBClient.delete_session/1` handles secure logout and cleanup

**Session Middleware Integration:**
The `AuthSession` plug provides seamless authentication integration across the entire application:
- **Automatic Validation**: Every request validates the user's session against the database
- **Fresh User Data**: Retrieves current user information from TMDB API for valid sessions
- **Context Injection**: Makes user data available in all LiveView components and controllers
- **Transparent Operation**: Works behind the scenes without requiring explicit session checks
- **Flexible Configuration**: Supports both optional and required authentication per route

**Security Features:**
- **Secure Cookies**: HTTP-only, secure, and SameSite cookie configuration
- **Session Encryption**: All session data is encrypted using Phoenix's signed cookies
- **Automatic Expiration**: Sessions automatically expire based on TMDB session lifetime
- **Background Cleanup**: Expired sessions are cleaned up automatically with database cleanup
- **CSRF Protection**: Built-in CSRF protection for authentication forms
- **Session Invalidation**: Automatic cleanup of invalid or expired sessions from cookies

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
- Unit tests for all contexts and modules
- Integration tests for complete user workflows
- Performance benchmarks and load testing
- Error handling and edge cases
- Mock testing for external API dependencies and context functions
- Authentication system testing with session management
- Security testing for authentication flows and session handling
- Continuous test maintenance with occasional adjustments for improved reliability

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
- **AuthSession Plug Testing**: Comprehensive middleware testing for session management
  - Session validation tests with valid, expired, and invalid sessions
  - User context injection tests with proper conn assign verification
  - Authentication requirement tests with redirect behavior
  - Helper function tests for session storage and retrieval
  - Security tests for session cleanup and cookie handling
  - Error handling tests for authentication failures and recovery
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
