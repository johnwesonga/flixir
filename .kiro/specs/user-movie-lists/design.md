# Design Document

## Overview

The user movie lists feature will enable authenticated users to create and manage personal movie collections using TMDB's native list management API. This feature builds upon the existing authentication system and integrates directly with TMDB's list endpoints to provide synchronized, persistent movie lists that work across the entire TMDB ecosystem.

The design follows Phoenix conventions and leverages the existing authentication infrastructure, introducing a new TMDB Lists API client and context for managing user-generated content. The feature will be implemented using Phoenix LiveView for real-time interactions with optimistic updates, local caching for performance, and comprehensive error handling for API reliability.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LiveView      │    │  Lists Context  │    │  Auth Context   │
│  (Presentation) │◄──►│ (Business Logic)│◄──►│ (User Sessions) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Components    │    │ TMDB Lists API  │    │  Cache Layer    │
│   (UI Elements) │    │    Client       │    │ (ETS/GenServer) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │  TMDB Lists     │    │  Local Storage  │
                       │     API         │    │  (Fallback)     │
                       └─────────────────┘    └─────────────────┘
```

### Context Integration

The user movie lists feature will introduce a new `Flixir.Lists` context that manages user-generated movie lists while integrating with:
- `Flixir.Auth` - For user authentication and session management with TMDB
- `Flixir.Lists.TMDBClient` - For direct integration with TMDB's list management API
- `Flixir.Lists.Cache` - For local caching and optimistic updates
- `Flixir.Lists.Queue` - For operation queuing when TMDB API is unavailable

## Components and Interfaces

### 1. TMDB Lists API Integration

**Primary Data Source:** TMDB Lists API endpoints

The system will primarily use TMDB's native list management API for all list operations:

- `POST /list` - Create a new list
- `GET /list/{list_id}` - Get list details
- `POST /list/{list_id}/add_item` - Add movie to list
- `POST /list/{list_id}/remove_item` - Remove movie from list
- `DELETE /list/{list_id}` - Delete list
- `POST /list/{list_id}/clear` - Clear all items from list
- `GET /account/{account_id}/lists` - Get user's lists

### 2. Local Cache Schema (Optional)

**Cache Tables for Performance:**

```sql
-- Cached list metadata for quick access
CREATE TABLE cached_user_lists (
  tmdb_list_id INTEGER PRIMARY KEY,
  tmdb_user_id INTEGER NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_public BOOLEAN DEFAULT false,
  item_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  cached_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  cache_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '1 hour'
);

-- Cached list items for offline access
CREATE TABLE cached_list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tmdb_list_id INTEGER NOT NULL,
  tmdb_movie_id INTEGER NOT NULL,
  added_at TIMESTAMP WITH TIME ZONE,
  cached_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(tmdb_list_id, tmdb_movie_id)
);

-- Operation queue for when TMDB API is unavailable
CREATE TABLE queued_list_operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_type VARCHAR(50) NOT NULL, -- 'create', 'update', 'delete', 'add_item', 'remove_item'
  tmdb_user_id INTEGER NOT NULL,
  tmdb_list_id INTEGER,
  operation_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  retry_count INTEGER DEFAULT 0,
  last_retry_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(20) DEFAULT 'pending' -- 'pending', 'processing', 'completed', 'failed'
);

-- Indexes for performance
CREATE INDEX idx_cached_user_lists_user_id ON cached_user_lists(tmdb_user_id);
CREATE INDEX idx_cached_user_lists_expires ON cached_user_lists(cache_expires_at);
CREATE INDEX idx_cached_list_items_list_id ON cached_list_items(tmdb_list_id);
CREATE INDEX idx_queued_operations_status ON queued_list_operations(status, created_at);
CREATE INDEX idx_queued_operations_user ON queued_list_operations(tmdb_user_id);
```

### 3. TMDB Lists API Client

**New TMDB Client Module:**

```elixir
defmodule Flixir.Lists.TMDBClient do
  @moduledoc """
  Client for TMDB Lists API integration.
  
  Handles all list management operations through TMDB's native API,
  including error handling, retry logic, and response parsing.
  """

  @doc "Create a new list on TMDB"
  def create_list(session_id, attrs) do
    params = %{
      name: attrs.name,
      description: attrs.description || "",
      public: attrs.is_public || false
    }
    
    post("/list", params, session_id)
  end

  @doc "Get list details from TMDB"
  def get_list(list_id, session_id) do
    get("/list/#{list_id}", %{}, session_id)
  end

  @doc "Add movie to TMDB list"
  def add_movie_to_list(list_id, movie_id, session_id) do
    params = %{media_id: movie_id}
    post("/list/#{list_id}/add_item", params, session_id)
  end

  @doc "Remove movie from TMDB list"
  def remove_movie_from_list(list_id, movie_id, session_id) do
    params = %{media_id: movie_id}
    post("/list/#{list_id}/remove_item", params, session_id)
  end

  @doc "Delete TMDB list"
  def delete_list(list_id, session_id) do
    delete("/list/#{list_id}", %{}, session_id)
  end

  @doc "Get user's lists from TMDB"
  def get_user_lists(account_id, session_id) do
    get("/account/#{account_id}/lists", %{}, session_id)
  end

  @doc "Clear all items from TMDB list"
  def clear_list(list_id, session_id) do
    post("/list/#{list_id}/clear", %{confirm: true}, session_id)
  end

  # Private HTTP client functions
  defp get(path, params, session_id), do: request(:get, path, params, session_id)
  defp post(path, params, session_id), do: request(:post, path, params, session_id)
  defp delete(path, params, session_id), do: request(:delete, path, params, session_id)

  defp request(method, path, params, session_id) do
    # Implementation with error handling, retries, and response parsing
  end
end
```

### 4. Cache Schemas (Optional)

**CachedUserList Schema:**

```elixir
defmodule Flixir.Lists.CachedUserList do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:tmdb_list_id, :integer, autogenerate: false}

  schema "cached_user_lists" do
    field :tmdb_user_id, :integer
    field :name, :string
    field :description, :string
    field :is_public, :boolean
    field :item_count, :integer
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
    field :cached_at, :utc_datetime
    field :cache_expires_at, :utc_datetime

    has_many :cached_items, Flixir.Lists.CachedListItem, foreign_key: :tmdb_list_id
  end

  def changeset(cached_list, attrs) do
    cached_list
    |> cast(attrs, [:tmdb_user_id, :name, :description, :is_public, :item_count, 
                    :created_at, :updated_at, :cached_at, :cache_expires_at])
    |> validate_required([:tmdb_list_id, :tmdb_user_id, :name])
  end
end
```

### 5. Lists Context with TMDB Integration

**Updated Context: `Flixir.Lists`**

```elixir
defmodule Flixir.Lists do
  @moduledoc """
  Context for managing user movie lists through TMDB API integration.
  
  Provides high-level functions for list management with optimistic updates,
  caching, and error handling. All operations are performed against TMDB's
  native list API with local caching for performance.
  """

  alias Flixir.Lists.{TMDBClient, Cache, Queue}
  alias Flixir.Auth

  # List Management Functions

  @spec create_list(integer(), map()) :: {:ok, map()} | {:error, term()}
  def create_list(tmdb_user_id, attrs) do
    with {:ok, session_id} <- get_user_session(tmdb_user_id),
         {:ok, tmdb_response} <- TMDBClient.create_list(session_id, attrs) do
      
      # Cache the new list locally
      Cache.put_list(tmdb_response)
      
      {:ok, tmdb_response}
    else
      {:error, :api_unavailable} ->
        # Queue operation for later
        Queue.enqueue_operation(:create_list, tmdb_user_id, nil, attrs)
        {:ok, :queued}
      
      error -> error
    end
  end

  @spec get_user_lists(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_user_lists(tmdb_user_id) do
    # Try cache first
    case Cache.get_user_lists(tmdb_user_id) do
      {:ok, cached_lists} when cached_lists != [] ->
        {:ok, cached_lists}
      
      _ ->
        # Fetch from TMDB API
        with {:ok, session_id} <- get_user_session(tmdb_user_id),
             {:ok, account_id} <- get_account_id(tmdb_user_id),
             {:ok, tmdb_lists} <- TMDBClient.get_user_lists(account_id, session_id) do
          
          # Cache the results
          Cache.put_user_lists(tmdb_user_id, tmdb_lists)
          
          {:ok, tmdb_lists}
        end
    end
  end

  # Helper functions
  defp get_user_session(tmdb_user_id) do
    Auth.get_user_session(tmdb_user_id)
  end

  defp get_account_id(tmdb_user_id) do
    Auth.get_account_id(tmdb_user_id)
  end
end
```

### 6. LiveView Implementation with TMDB Integration

**Updated LiveView: `FlixirWeb.UserMovieListsLive`**

```elixir
%{
  current_user: map() | nil,
  lists: [map()],  # TMDB list objects
  selected_list: map() | nil,
  list_movies: [map()],
  loading: boolean(),
  error: String.t() | nil,
  show_form: :create | :edit | nil,
  form_data: map(),
  lists_summary: map(),
  # New TMDB-specific state
  tmdb_session_id: String.t() | nil,
  optimistic_updates: [map()],  # Track pending operations
  queued_operations: [map()],   # Operations waiting for API
  sync_status: :synced | :syncing | :error | :offline
}
```

**Events handled with optimistic updates:**
- `"create_list"` - Create a new TMDB list with optimistic UI update
- `"edit_list"` - Edit existing TMDB list details
- `"delete_list"` - Delete a TMDB list with confirmation
- `"clear_list"` - Remove all movies from TMDB list
- `"select_list"` - View a specific TMDB list
- `"add_movie"` - Add a movie to TMDB list with optimistic update
- `"remove_movie"` - Remove a movie from TMDB list with optimistic update
- `"toggle_privacy"` - Change TMDB list privacy setting
- `"retry_failed_operations"` - Retry queued operations when API is available
- `"sync_with_tmdb"` - Force synchronization with TMDB API

**Updated LiveView: `FlixirWeb.UserMovieListLive` (Single List View)**

State management with TMDB integration:
```elixir
%{
  current_user: map() | nil,
  list: map() | nil,  # TMDB list object
  movies: [map()],
  loading: boolean(),
  error: String.t() | nil,
  editing: boolean(),
  form_data: map(),
  stats: map(),
  # New TMDB-specific state
  tmdb_list_id: integer() | nil,
  tmdb_session_id: String.t() | nil,
  optimistic_movies: [map()],  # Movies being added/removed optimistically
  sync_status: :synced | :syncing | :error | :offline,
  last_sync_at: DateTime.t() | nil
}
```

### 5. UI Components

**New Component: `FlixirWeb.UserMovieListComponents`**

```elixir
# Lists overview container
def user_lists_container(assigns)

# Individual list card
def list_card(assigns)

# List creation/edit form
def list_form(assigns)

# List statistics display
def list_stats(assigns)

# Movie grid within a list
def list_movies_grid(assigns)

# Add to list modal/dropdown
def add_to_list_selector(assigns)

# Empty state for no lists
def empty_lists_state(assigns)

# Confirmation modals
def delete_confirmation_modal(assigns)
def clear_confirmation_modal(assigns)
```

**Enhanced Components:**
- Extend `FlixirWeb.SearchComponents` to include "Add to List" functionality
- Extend `FlixirWeb.MovieDetailsLive` to show list membership and add/remove options

### 6. Routing

**New Routes:**
```elixir
# User movie lists management
live "/my-lists", UserMovieListsLive, :index
live "/my-lists/new", UserMovieListsLive, :new
live "/my-lists/:id", UserMovieListLive, :show
live "/my-lists/:id/edit", UserMovieListLive, :edit

# API routes for AJAX operations
post "/api/lists", UserMovieListController, :create
put "/api/lists/:id", UserMovieListController, :update
delete "/api/lists/:id", UserMovieListController, :delete
post "/api/lists/:id/movies", UserMovieListController, :add_movie
delete "/api/lists/:id/movies/:movie_id", UserMovieListController, :remove_movie
```

## Data Models

### List Data Structure

```elixir
%UserMovieList{
  id: "uuid-string",
  name: "My Watchlist",
  description: "Movies I want to watch",
  is_public: false,
  tmdb_user_id: 12345,
  inserted_at: ~U[2024-01-01 12:00:00Z],
  updated_at: ~U[2024-01-01 12:00:00Z],
  list_items: [%UserMovieListItem{}, ...],
  movies: [movie_data, ...]
}
```

### List Item Data Structure

```elixir
%UserMovieListItem{
  id: "uuid-string",
  list_id: "list-uuid",
  tmdb_movie_id: 550,
  added_at: ~U[2024-01-01 12:00:00Z],
  inserted_at: ~U[2024-01-01 12:00:00Z]
}
```

### Movie Data Integration

Movies will be fetched from TMDB API using existing `Flixir.Media` functions and combined with list metadata:

```elixir
%{
  # TMDB movie data
  id: 550,
  title: "Fight Club",
  poster_path: "/path/to/poster.jpg",
  release_date: "1999-10-15",
  overview: "Movie description...",
  vote_average: 8.8,
  
  # List-specific metadata
  added_at: ~U[2024-01-01 12:00:00Z],
  list_id: "uuid-string"
}
```

## Error Handling with TMDB Integration

### Error Types

- `:unauthorized` - User not authenticated or accessing another user's TMDB list
- `:not_found` - TMDB list or movie not found
- `:validation_error` - Invalid input data for TMDB API
- `:duplicate_movie` - Attempting to add movie already in TMDB list
- `:tmdb_api_error` - TMDB API failures (rate limits, server errors, etc.)
- `:session_expired` - TMDB session expired, requires re-authentication
- `:api_unavailable` - TMDB API temporarily unavailable
- `:network_error` - Network connectivity issues
- `:quota_exceeded` - TMDB API quota exceeded

### Error Recovery with Queue System

- **Validation errors**: Display inline form errors with field-specific messages
- **Not found errors**: Redirect to lists overview with error message
- **Unauthorized access**: Redirect to login or show access denied message
- **TMDB API errors**: Queue operations for retry, show cached data when available
- **Session expired**: Automatically refresh TMDB session and retry operation
- **API unavailable**: Queue operations, show offline mode with cached data
- **Network errors**: Implement exponential backoff retry with user notification

### Optimistic Updates and Rollback

```elixir
# Optimistic update flow
1. Update UI immediately
2. Send request to TMDB API
3. On success: confirm update, update cache
4. On failure: rollback UI, show error, queue for retry

# Example rollback scenarios
- Movie addition fails -> Remove from UI, show error
- List creation fails -> Remove optimistic list, show error
- List deletion fails -> Restore list in UI, show error
```

### User Feedback with TMDB Context

```elixir
# Success messages
"List created successfully on TMDB!"
"Movie added to your TMDB list"
"List updated and synced with TMDB"
"Changes synced with TMDB"

# Error messages with context
"TMDB API is temporarily unavailable. Your changes have been queued."
"Failed to sync with TMDB. Retrying in background..."
"TMDB session expired. Please log in again."
"List not found on TMDB. It may have been deleted."
"TMDB API rate limit reached. Please try again later."

# Queue status messages
"3 operations pending sync with TMDB"
"Syncing changes with TMDB..."
"All changes synced successfully"
"Some operations failed. Click to retry."
```

## Testing Strategy

### Unit Tests

**Lists Context Tests:**
- Test CRUD operations for lists and list items
- Test user authorization and data isolation
- Test validation rules and constraints
- Test statistics and summary functions

**Schema Tests:**
- Test changeset validations
- Test database constraints
- Test associations and preloading

### Integration Tests

**LiveView Tests:**
- Test authenticated user workflows
- Test list creation, editing, and deletion
- Test movie addition and removal
- Test privacy settings and access control

**Component Tests:**
- Test list display components
- Test form components with validation
- Test modal interactions
- Test responsive behavior

### End-to-End Tests

**User Journey Tests:**
- Complete list management workflow
- Movie discovery to list addition flow
- List sharing and privacy scenarios
- Error handling and recovery flows

## Security Considerations

### Authentication & Authorization

- All list operations require valid TMDB session
- Users can only access and modify their own lists
- Public lists are read-only for other users
- Session validation on every request

### Data Validation

- Server-side validation for all inputs
- SQL injection prevention through Ecto
- XSS prevention in templates
- CSRF protection for state-changing operations

### Privacy Controls

- Private lists are never exposed to other users
- Public lists show only basic information
- User data isolation at database level
- Audit logging for sensitive operations

## Performance Considerations

### Database Optimization

- Proper indexing on frequently queried fields
- Efficient queries with appropriate preloading
- Pagination for large lists
- Database connection pooling

### Caching Strategy

- Cache movie data from TMDB API
- Cache user list summaries
- Cache public list data
- TTL-based cache invalidation

### UI Performance

- Lazy loading for large movie lists
- Optimistic updates for better UX
- Debounced search and filtering
- Efficient re-rendering with LiveView

## Implementation Notes

### Migration Strategy

1. Create database migrations for new tables
2. Add indexes and constraints
3. Implement schemas and context functions
4. Build LiveView components incrementally
5. Add routing and integrate with existing features

### Integration Points

- **Movie Details Page**: Add "Add to List" functionality
- **Search Results**: Bulk add to list options
- **Navigation**: Add "My Lists" menu item
- **User Profile**: Show list statistics

### Mobile Responsiveness

- Touch-friendly list management interface
- Responsive grid layouts for movie displays
- Mobile-optimized forms and modals
- Gesture support for common actions

### Accessibility

- Keyboard navigation for all interactions
- Screen reader support with proper ARIA labels
- High contrast mode compatibility
- Focus management in modals and forms