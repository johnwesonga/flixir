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

**Auth Context (`lib/flixir/auth.ex`)**
- Manages user authentication and session handling
- Integrates with TMDB's session-based authentication system through TMDBClient
- Provides secure session storage and validation with comprehensive logging
- Handles user account management and session cleanup
- Implements complete authentication flow with proper error handling and logging
- Includes session validation, user data retrieval, and secure logout functionality

**Auth Session Plug (`lib/flixir_web/plugs/auth_session.ex`)**
- Middleware for automatic session validation and user context injection
- Validates TMDB session IDs from cookies against the database on every request
- Injects current user data and authentication status into conn assigns
- Handles expired session cleanup and authentication requirements
- Provides helper functions for session management (put/clear session ID, redirect handling)
- Supports both optional and required authentication with configurable redirect behavior
- Comprehensive logging for authentication events and security monitoring

**Search Live View (`lib/flixir_web/live/search_live.ex`)**
- Real-time search interface with debounced input (300ms)
- Handles URL parameters for shareable search links
- Manages search state including pagination, filtering, and sorting
- Implements comprehensive error handling and validation

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

**Caching System (`lib/flixir/media/cache.ex`)**
- In-memory caching for search results and content details
- Configurable TTL (5 minutes for search, 30 minutes for details)
- Provides cache statistics and management functions

### Data Flow

**Search Flow:**
1. User input → SearchLive (debounced validation)
2. SearchLive → Media context (search orchestration)
3. Media → Cache (check for cached results)
4. Cache miss → TMDB Client (API call)
5. TMDB Client → Media (transform and cache response)
6. Media → SearchLive (display results)

**Authentication Flow:**
1. Every request → AuthSession plug (session validation)
2. AuthSession → Auth context (validate session against database)
3. Auth context → TMDB API (get fresh user data for valid sessions)
4. AuthSession → conn assigns (inject user context: current_user, current_session, authenticated?)
5. LiveView/Controller → access user data from conn assigns
6. Optional: Redirect to login if authentication required and user not authenticated

### Key Features
- **Debounced Search**: 300ms delay to reduce API calls
- **Pagination**: 20 results per page with lazy loading
- **Filtering**: By content type (movies, TV shows, both)
- **Sorting**: By relevance, popularity, release date, or title
- **Caching**: Optimized API usage with intelligent cache management
- **Error Handling**: Comprehensive error states and recovery
- **Authentication**: TMDB-based user authentication with automatic session management
- **Session Management**: Transparent session validation and user context injection across all requests
- **Security**: Secure session storage, automatic cleanup, and comprehensive logging

### Configuration
- Database: PostgreSQL with Ecto
- HTTP Client: Req library for TMDB API calls
- Frontend: Phoenix LiveView with Tailwind CSS
- Server: Bandit adapter

### Development Notes
- Uses Phoenix 1.8 with LiveView for real-time interactions
- Built with Kiro framework principles
- Comprehensive test coverage including integration, performance, and error handling tests
- Mock-based testing for external API dependencies

### Testing Structure
- **Unit Tests**: `test/flixir/media/` - Test individual components
- **LiveView Tests**: `test/flixir_web/live/` - Test user interactions
- **Integration Tests**: `test/flixir_web/integration/` - Test complete workflows including comprehensive movie lists integration testing
- **Performance Tests**: Measure search response times, concurrent usage, and system performance under load

### Environment-Specific Configuration
- Development: Live reloading, debug logging, local mailbox
- Test: Quiet database setup, mocked external dependencies
- Production: Optimized assets, secure headers, proper error handling