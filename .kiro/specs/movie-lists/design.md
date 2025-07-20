# Design Document

## Overview

The movie lists feature will extend the existing Flixir application to provide curated lists of movies such as popular, trending, top-rated, upcoming, and now playing. This feature will integrate with the existing TMDB API client and caching infrastructure while following the established Phoenix LiveView patterns used in the search functionality.

The design leverages the existing Media context architecture and introduces new TMDB API endpoints for retrieving movie lists. The feature will be implemented as a new LiveView with reusable components for displaying movie grids and navigation between different list types.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LiveView      │    │  Media Context  │    │  TMDB Client    │
│  (Presentation) │◄──►│ (Business Logic)│◄──►│   (API Layer)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Components    │    │     Cache       │    │   HTTP Client   │
│   (UI Elements) │    │   (ETS Store)   │    │     (Req)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Context Integration

The movie lists feature will extend the existing `Flixir.Media` context with new functions for retrieving different types of movie lists. This maintains consistency with the current architecture and allows reuse of existing caching and error handling mechanisms.

## Components and Interfaces

### 1. Media Context Extensions

**New Functions in `Flixir.Media`:**

```elixir
# Get popular movies
@spec get_popular_movies(keyword()) :: {:ok, [SearchResult.t()]} | {:error, term()}
def get_popular_movies(opts \\ [])

# Get trending movies  
@spec get_trending_movies(keyword()) :: {:ok, [SearchResult.t()]} | {:error, term()}
def get_trending_movies(opts \\ [])

# Get top-rated movies
@spec get_top_rated_movies(keyword()) :: {:ok, [SearchResult.t()]} | {:error, term()}
def get_top_rated_movies(opts \\ [])

# Get upcoming movies
@spec get_upcoming_movies(keyword()) :: {:ok, [SearchResult.t()]} | {:error, term()}
def get_upcoming_movies(opts \\ [])

# Get now playing movies
@spec get_now_playing_movies(keyword()) :: {:ok, [SearchResult.t()]} | {:error, term()}
def get_now_playing_movies(opts \\ [])
```

**Options supported:**
- `:page` - Page number for pagination (default: 1)
- `:return_format` - `:list` or `:map` format (default: `:map`)

### 2. TMDB Client Extensions

**New Functions in `Flixir.Media.TMDBClient`:**

```elixir
# Get popular movies from TMDB
@spec get_popular_movies(integer()) :: {:ok, map()} | {:error, term()}
def get_popular_movies(page \\ 1)

# Get trending movies from TMDB
@spec get_trending_movies(String.t(), integer()) :: {:ok, map()} | {:error, term()}
def get_trending_movies(time_window \\ "week", page \\ 1)

# Get top-rated movies from TMDB
@spec get_top_rated_movies(integer()) :: {:ok, map()} | {:error, term()}
def get_top_rated_movies(page \\ 1)

# Get upcoming movies from TMDB
@spec get_upcoming_movies(integer()) :: {:ok, map()} | {:error, term()}
def get_upcoming_movies(page \\ 1)

# Get now playing movies from TMDB
@spec get_now_playing_movies(integer()) :: {:ok, map()} | {:error, term()}
def get_now_playing_movies(page \\ 1)
```

### 3. LiveView Implementation

**New LiveView: `FlixirWeb.MovieListsLive`**

State management:
```elixir
%{
  current_list: :popular | :trending | :top_rated | :upcoming | :now_playing,
  movies: [SearchResult.t()],
  loading: boolean(),
  error: String.t() | nil,
  page: integer(),
  has_more: boolean(),
  page_title: String.t()
}
```

**Events handled:**
- `"switch_list"` - Change between different movie list types
- `"load_more"` - Load additional pages of results
- `"retry"` - Retry failed requests

### 4. UI Components

**New Component: `FlixirWeb.MovieListComponents`**

```elixir
# Main movie lists container
def movie_lists_container(assigns)

# Navigation tabs for switching between lists
def list_navigation(assigns)

# Movie grid display
def movie_grid(assigns)

# Individual movie card
def movie_card(assigns)

# Load more button/infinite scroll trigger
def load_more_section(assigns)
```

**Reused Components:**
- `FlixirWeb.LoadingComponents` - Loading states
- `FlixirWeb.EmptyStateComponents` - Empty and error states

### 5. Routing

**New Route:**
```elixir
live "/movies", MovieListsLive, :index
live "/movies/:list_type", MovieListsLive, :show
```

URL parameters:
- `:list_type` - popular, trending, top-rated, upcoming, now-playing
- `?page=N` - Pagination support

## Data Models

### Movie List Result

The existing `Flixir.Media.SearchResult` struct will be reused for consistency:

```elixir
%Flixir.Media.SearchResult{
  id: integer(),
  title: String.t(),
  media_type: :movie,  # Always :movie for movie lists
  release_date: Date.t() | nil,
  overview: String.t() | nil,
  poster_path: String.t() | nil,
  genre_ids: [integer()],
  vote_average: float(),
  popularity: float()
}
```

### Cache Keys

Cache keys will follow the existing pattern:
- `"movies:popular:page:1"`
- `"movies:trending:week:page:1"`
- `"movies:top_rated:page:1"`
- `"movies:upcoming:page:1"`
- `"movies:now_playing:page:1"`

### API Response Transformation

TMDB API responses will be transformed using the existing `SearchResult.from_tmdb_data/1` function to maintain consistency with search results.

## Error Handling

### Error Types

The feature will handle the same error types as the existing search functionality:
- `:timeout` - API request timeouts
- `:rate_limited` - TMDB API rate limiting
- `:unauthorized` - Invalid API key
- `:api_error` - General API errors
- `:network_error` - Network connectivity issues
- `:transformation_error` - Data parsing errors

### Error Recovery

- **Retry mechanism**: Users can retry failed requests
- **Graceful degradation**: Show cached results when API is unavailable
- **Fallback behavior**: Default to popular movies if specific list fails
- **User feedback**: Clear error messages with actionable guidance

### Logging

Error logging will follow existing patterns:
```elixir
Logger.error("Failed to fetch #{list_type} movies: #{inspect(reason)}")
Logger.warning("Cache miss for #{list_type} movies, page #{page}")
Logger.info("Successfully cached #{list_type} movies, page #{page}")
```

## Testing Strategy

### Unit Tests

**Media Context Tests:**
- Test each new movie list function
- Test caching behavior for movie lists
- Test error handling and transformation
- Test pagination logic

**TMDB Client Tests:**
- Mock API responses for each endpoint
- Test error scenarios (timeouts, rate limits, etc.)
- Test parameter validation

**Component Tests:**
- Test movie list component rendering
- Test navigation between list types
- Test loading and error states
- Test movie card display

### Integration Tests

**LiveView Tests:**
- Test full user workflows (switching lists, pagination)
- Test URL parameter handling
- Test real-time updates and state management
- Test error recovery flows

**API Integration Tests:**
- Test actual TMDB API integration (with test API key)
- Test rate limiting behavior
- Test response parsing and transformation

### Performance Tests

**Load Testing:**
- Test concurrent requests to different movie lists
- Test cache performance under load
- Test memory usage with large result sets

**Caching Tests:**
- Test cache hit/miss ratios
- Test cache expiration behavior
- Test cache eviction under memory pressure

## Implementation Notes

### Caching Strategy

- **TTL**: 15 minutes for movie lists (longer than search results due to less frequent updates)
- **Cache warming**: Pre-load popular movies on application start
- **Cache invalidation**: Manual cache clearing for administrative purposes

### Performance Considerations

- **Lazy loading**: Load movie lists on demand
- **Image optimization**: Use TMDB's image resizing for different screen sizes
- **Infinite scroll**: Implement smooth pagination for better UX
- **Debouncing**: Prevent rapid API calls during navigation

### Mobile Responsiveness

- **Touch-friendly navigation**: Large tap targets for list switching
- **Responsive grid**: Adaptive movie card layout for different screen sizes
- **Optimized images**: Serve appropriate image sizes for mobile devices
- **Gesture support**: Swipe navigation between list types

### Accessibility

- **Keyboard navigation**: Full keyboard support for list navigation
- **Screen reader support**: Proper ARIA labels and descriptions
- **Focus management**: Logical tab order and focus indicators
- **High contrast**: Support for high contrast mode and dark themes