# Design Document

## Overview

The user movie lists feature will enable authenticated users to create and manage personal movie collections within the Flixir application. This feature builds upon the existing authentication system and integrates with the TMDB API to provide rich movie data while storing user-specific list information in the local database.

The design follows Phoenix conventions and leverages the existing authentication infrastructure, introducing new database schemas for lists and list items, along with a new context for managing user-generated content. The feature will be implemented using Phoenix LiveView for real-time interactions and responsive user experience.

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
│   Components    │    │   Database      │    │  Media Context  │
│   (UI Elements) │    │   (PostgreSQL)  │    │  (Movie Data)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Context Integration

The user movie lists feature will introduce a new `Flixir.Lists` context that manages user-generated movie lists while integrating with:
- `Flixir.Auth` - For user authentication and session management
- `Flixir.Media` - For movie data and TMDB integration
- Database schemas for persistent storage of lists and list items

## Components and Interfaces

### 1. Database Schema Design

**New Tables:**

```sql
-- User movie lists
CREATE TABLE user_movie_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_public BOOLEAN DEFAULT false,
  tmdb_user_id INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Movies in lists (junction table)
CREATE TABLE user_movie_list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id UUID NOT NULL REFERENCES user_movie_lists(id) ON DELETE CASCADE,
  tmdb_movie_id INTEGER NOT NULL,
  added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_user_movie_lists_tmdb_user_id ON user_movie_lists(tmdb_user_id);
CREATE INDEX idx_user_movie_lists_updated_at ON user_movie_lists(updated_at DESC);
CREATE INDEX idx_user_movie_list_items_list_id ON user_movie_list_items(list_id);
CREATE INDEX idx_user_movie_list_items_tmdb_movie_id ON user_movie_list_items(tmdb_movie_id);
CREATE UNIQUE INDEX idx_unique_movie_per_list ON user_movie_list_items(list_id, tmdb_movie_id);
```

### 2. Ecto Schemas

**UserMovieList Schema:**

```elixir
defmodule Flixir.Lists.UserMovieList do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_movie_lists" do
    field :name, :string
    field :description, :string
    field :is_public, :boolean, default: false
    field :tmdb_user_id, :integer

    has_many :list_items, Flixir.Lists.UserMovieListItem, foreign_key: :list_id
    has_many :movies, through: [:list_items, :movie]

    timestamps()
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :description, :is_public, :tmdb_user_id])
    |> validate_required([:name, :tmdb_user_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:tmdb_user_id, greater_than: 0)
  end
end
```

**UserMovieListItem Schema:**

```elixir
defmodule Flixir.Lists.UserMovieListItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_movie_list_items" do
    field :tmdb_movie_id, :integer
    field :added_at, :utc_datetime

    belongs_to :list, Flixir.Lists.UserMovieList, foreign_key: :list_id, type: :binary_id

    timestamps(updated_at: false)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:tmdb_movie_id, :list_id, :added_at])
    |> validate_required([:tmdb_movie_id, :list_id])
    |> validate_number(:tmdb_movie_id, greater_than: 0)
    |> maybe_set_added_at()
    |> unique_constraint([:list_id, :tmdb_movie_id], name: :idx_unique_movie_per_list)
  end

  defp maybe_set_added_at(changeset) do
    case get_field(changeset, :added_at) do
      nil -> put_change(changeset, :added_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
```

### 3. Lists Context

**New Context: `Flixir.Lists`**

```elixir
defmodule Flixir.Lists do
  @moduledoc """
  Context for managing user movie lists.
  """

  import Ecto.Query, warn: false
  alias Flixir.Repo
  alias Flixir.Lists.{UserMovieList, UserMovieListItem}
  alias Flixir.Media

  # List Management Functions

  @spec create_list(integer(), map()) :: {:ok, UserMovieList.t()} | {:error, Ecto.Changeset.t()}
  def create_list(tmdb_user_id, attrs)

  @spec get_user_lists(integer()) :: [UserMovieList.t()]
  def get_user_lists(tmdb_user_id)

  @spec get_list(binary(), integer()) :: {:ok, UserMovieList.t()} | {:error, :not_found}
  def get_list(list_id, tmdb_user_id)

  @spec update_list(UserMovieList.t(), map()) :: {:ok, UserMovieList.t()} | {:error, Ecto.Changeset.t()}
  def update_list(list, attrs)

  @spec delete_list(UserMovieList.t()) :: {:ok, UserMovieList.t()} | {:error, Ecto.Changeset.t()}
  def delete_list(list)

  @spec clear_list(UserMovieList.t()) :: {:ok, {integer(), nil}} | {:error, term()}
  def clear_list(list)

  # Movie Management Functions

  @spec add_movie_to_list(binary(), integer(), integer()) :: {:ok, UserMovieListItem.t()} | {:error, term()}
  def add_movie_to_list(list_id, tmdb_movie_id, tmdb_user_id)

  @spec remove_movie_from_list(binary(), integer(), integer()) :: {:ok, UserMovieListItem.t()} | {:error, term()}
  def remove_movie_from_list(list_id, tmdb_movie_id, tmdb_user_id)

  @spec get_list_movies(binary(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_list_movies(list_id, tmdb_user_id)

  @spec movie_in_list?(binary(), integer()) :: boolean()
  def movie_in_list?(list_id, tmdb_movie_id)

  # Statistics Functions

  @spec get_list_stats(binary()) :: map()
  def get_list_stats(list_id)

  @spec get_user_lists_summary(integer()) :: map()
  def get_user_lists_summary(tmdb_user_id)
end
```

### 4. LiveView Implementation

**New LiveView: `FlixirWeb.UserMovieListsLive`**

State management:
```elixir
%{
  current_user: map() | nil,
  lists: [UserMovieList.t()],
  selected_list: UserMovieList.t() | nil,
  list_movies: [map()],
  loading: boolean(),
  error: String.t() | nil,
  show_form: :create | :edit | nil,
  form_data: map(),
  lists_summary: map()
}
```

**Events handled:**
- `"create_list"` - Create a new movie list
- `"edit_list"` - Edit existing list details
- `"delete_list"` - Delete a movie list
- `"clear_list"` - Remove all movies from a list
- `"select_list"` - View a specific list
- `"add_movie"` - Add a movie to a list
- `"remove_movie"` - Remove a movie from a list
- `"toggle_privacy"` - Change list privacy setting

**New LiveView: `FlixirWeb.UserMovieListLive` (Single List View)**

State management:
```elixir
%{
  current_user: map() | nil,
  list: UserMovieList.t() | nil,
  movies: [map()],
  loading: boolean(),
  error: String.t() | nil,
  editing: boolean(),
  form_data: map(),
  stats: map()
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

## Error Handling

### Error Types

- `:unauthorized` - User not authenticated or accessing another user's list
- `:not_found` - List or movie not found
- `:validation_error` - Invalid input data
- `:duplicate_movie` - Attempting to add movie already in list
- `:database_error` - Database operation failures
- `:api_error` - TMDB API errors when fetching movie data

### Error Recovery

- **Validation errors**: Display inline form errors with field-specific messages
- **Not found errors**: Redirect to lists overview with error message
- **Unauthorized access**: Redirect to login or show access denied message
- **Database errors**: Show retry option and log for investigation
- **API errors**: Show cached movie data when available, graceful degradation

### User Feedback

```elixir
# Success messages
"List created successfully!"
"Movie added to your list"
"List updated"

# Error messages
"You can only edit your own lists"
"This movie is already in your list"
"Failed to load movie data. Please try again."
"List name must be between 3 and 100 characters"
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