# Routing Structure Changes

## Summary

The application routing has been significantly expanded to support comprehensive TMDB list management through both web interface and REST API. This update introduces a complete API layer for list operations, public list sharing, and queue management.

## Changes Made

### New Route Scopes

#### 1. Enhanced Authenticated Routes (`/`)
- **Added**: `/my-lists/new` - Create new TMDB lists
- **Updated**: `/my-lists/:tmdb_list_id` - Now uses TMDB list IDs with integer constraints
- **Added**: `/my-lists/:tmdb_list_id/edit` - Edit existing TMDB lists

#### 2. Public List Sharing Routes (`/lists`)
- **Added**: `/lists/public/:tmdb_list_id` - View public TMDB lists without authentication
- **Added**: `/lists/shared/:tmdb_list_id` - Access shared TMDB lists via direct links
- **Added**: `/lists/external/:tmdb_list_id` - Redirect to TMDB's native list page

#### 3. Public API Routes (`/api`)
- **Added**: `GET /api/lists/public/:tmdb_list_id` - Get public list data
- **Added**: `GET /api/lists/shared/:tmdb_list_id` - Get shared list data

#### 4. Protected API Routes (`/api`)
**List CRUD Operations:**
- **Added**: `POST /api/lists` - Create new TMDB list
- **Added**: `GET /api/lists` - Get all user's TMDB lists
- **Added**: `GET /api/lists/:tmdb_list_id` - Get specific TMDB list
- **Added**: `PUT /api/lists/:tmdb_list_id` - Update TMDB list details
- **Added**: `DELETE /api/lists/:tmdb_list_id` - Delete TMDB list
- **Added**: `POST /api/lists/:tmdb_list_id/clear` - Clear all movies from TMDB list

**Movie Management:**
- **Added**: `POST /api/lists/:tmdb_list_id/movies` - Add movie to TMDB list
- **Added**: `DELETE /api/lists/:tmdb_list_id/movies/:tmdb_movie_id` - Remove movie from TMDB list

**Sharing & Privacy:**
- **Added**: `POST /api/lists/:tmdb_list_id/share` - Generate sharing links
- **Added**: `POST /api/lists/:tmdb_list_id/privacy` - Update privacy settings

**Sync Operations:**
- **Added**: `POST /api/lists/sync` - Sync all user's TMDB lists
- **Added**: `POST /api/lists/:tmdb_list_id/sync` - Sync specific TMDB list
- **Added**: `GET /api/lists/sync/status` - Get synchronization status

**Queue Management:**
- **Added**: `GET /api/lists/queue` - Get queued operations
- **Added**: `POST /api/lists/queue/retry` - Retry all failed operations
- **Added**: `POST /api/lists/queue/:operation_id/retry` - Retry specific operation
- **Added**: `DELETE /api/lists/queue/:operation_id` - Cancel queued operation
- **Added**: `GET /api/lists/queue/stats` - Get queue statistics

### Route Constraints

#### TMDB List ID Constraint
```elixir
constraints: %{tmdb_list_id: ~r/\d+/}
```
- Ensures TMDB list IDs are integers
- Applied to all routes with `:tmdb_list_id` parameter
- Provides clear error handling for invalid IDs

#### TMDB Movie ID Constraint
```elixir
constraints: %{tmdb_list_id: ~r/\d+/, tmdb_movie_id: ~r/\d+/}
```
- Ensures both list and movie IDs are integers
- Applied to movie management endpoints

### Pipeline Updates

#### New `:require_auth` Pipeline
```elixir
pipeline :require_auth do
  plug FlixirWeb.Plugs.AuthSession, require_auth: true
end
```
- Dedicated pipeline for API authentication enforcement
- Returns JSON error responses for unauthenticated requests
- Used in combination with `:api` pipeline for protected endpoints

### New Controllers

#### `FlixirWeb.Api.ListController`
- Comprehensive TMDB list management API
- Handles CRUD operations, movie management, and sharing
- Supports both public and protected endpoints

#### `FlixirWeb.Api.SyncController`
- Synchronization operations for TMDB lists
- Cache management and sync status reporting
- Background sync coordination

#### `FlixirWeb.Api.QueueController`
- Queue management for offline operations
- Retry logic and operation monitoring
- Statistics and status reporting

### New LiveView Modules

#### `FlixirWeb.PublicListLive`
- Public TMDB list viewing without authentication
- Optimized for sharing and discovery

#### `FlixirWeb.SharedListLive`
- Shared TMDB list access via direct links
- Enhanced sharing functionality

### Route Organization Improvements

#### Logical Grouping
- **Web Routes**: User-facing interfaces with LiveView
- **List Sharing**: Public access and external redirects
- **API Routes**: Programmatic access with proper authentication

#### Route Ordering
- Static routes placed before parameterized routes
- Prevents route conflicts and ensures proper matching
- Sync and queue routes placed before generic list routes

## Impact

### For Developers
- **Comprehensive API**: Full REST API for TMDB list management
- **Clear Structure**: Logical route organization with proper constraints
- **Authentication**: Consistent authentication across web and API
- **Documentation**: Complete API documentation with examples

### For Users
- **Public Sharing**: Share TMDB lists without requiring authentication
- **External Links**: Direct integration with TMDB's native interface
- **API Access**: Programmatic access to list management features
- **Offline Support**: Queue system for reliable operations

### For Integration
- **REST API**: Standard REST endpoints for external integrations
- **Public Access**: Read-only access to public lists without authentication
- **Webhook Ready**: Structure supports future webhook implementations
- **Versioning Ready**: Route structure supports future API versioning

## Documentation Updates

### New Documentation Files
1. **`docs/api_endpoints.md`**: Comprehensive API documentation with examples
2. **`docs/routing_structure.md`**: Detailed routing organization and pipeline documentation

### Updated Documentation
1. **`README.md`**: Updated with new API routes and architecture information
2. **Route testing examples**: Added API controller and route constraint testing

## Migration

### Existing Routes
- All existing routes remain unchanged and fully compatible
- No breaking changes to existing functionality
- Backward compatibility maintained

### New Features
- New routes are additive and don't affect existing functionality
- API endpoints follow RESTful conventions
- Authentication requirements are clearly documented

## Testing

### New Test Coverage
- API controller tests for all new endpoints
- Route constraint validation tests
- Authentication flow tests for API endpoints
- Public list access tests
- Queue management operation tests

### Test Organization
```bash
# API controller tests
mix test test/flixir_web/controllers/api/

# Route tests
mix test test/flixir_web/router_test.exs

# LiveView tests for new modules
mix test test/flixir_web/live/public_list_live_test.exs
mix test test/flixir_web/live/shared_list_live_test.exs
```

## Future Considerations

### API Versioning
- Route structure supports explicit versioning (e.g., `/api/v2/`)
- Current routes are implicitly v1

### Webhook Support
- Route structure ready for webhook endpoint addition
- Authentication framework supports webhook validation

### Rate Limiting
- Route organization supports future rate limiting implementation
- API endpoints ready for rate limiting middleware

## Benefits

- **Comprehensive API**: Complete REST API for all list operations
- **Public Sharing**: Enhanced sharing capabilities without authentication barriers
- **Developer Experience**: Clear, documented API with consistent patterns
- **Scalability**: Route structure supports future enhancements and integrations
- **Security**: Proper authentication boundaries between public and protected routes
- **Maintainability**: Logical organization makes routes easy to understand and maintain