# API Endpoints Documentation

This document provides comprehensive documentation for Flixir's REST API endpoints for TMDB list management.

## Base URL

All API endpoints are prefixed with `/api` and return JSON responses.

## Authentication

The API uses session-based authentication with TMDB:
- **Public endpoints**: No authentication required
- **Protected endpoints**: Require valid TMDB session cookie
- **Session validation**: Performed on each request to protected endpoints

## Response Format

### Success Response
```json
{
  "data": { ... },
  "status": "success",
  "message": "Operation completed successfully"
}
```

### Error Response
```json
{
  "error": "error_type",
  "message": "Human-readable error message",
  "details": {
    "field": "validation error details"
  }
}
```

## Public API Endpoints

These endpoints do not require authentication and provide read-only access to public/shared lists.

### Get Public List
```
GET /api/lists/public/:tmdb_list_id
```

**Description**: Retrieve details of a public TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Response**:
```json
{
  "data": {
    "id": 12345,
    "name": "Best Action Movies",
    "description": "My favorite action movies",
    "public": true,
    "item_count": 25,
    "created_by": "username",
    "items": [...]
  },
  "status": "success"
}
```

**Error Codes**:
- `404`: List not found or not public
- `500`: Server error

### Get Shared List
```
GET /api/lists/shared/:tmdb_list_id
```

**Description**: Retrieve details of a shared TMDB list (accessible via direct link).

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Response**: Same as public list endpoint

**Error Codes**:
- `404`: List not found or not accessible
- `500`: Server error

## Protected API Endpoints

These endpoints require authentication via valid TMDB session.

### List Management

#### Create List
```
POST /api/lists
```

**Description**: Create a new TMDB list.

**Request Body**:
```json
{
  "name": "My New List",
  "description": "Description of the list",
  "public": false
}
```

**Response**:
```json
{
  "data": {
    "id": 12345,
    "name": "My New List",
    "description": "Description of the list",
    "public": false,
    "item_count": 0
  },
  "status": "success",
  "message": "List created successfully"
}
```

**Error Codes**:
- `400`: Invalid request data
- `401`: Authentication required
- `422`: Validation errors
- `500`: Server error

#### Get All Lists
```
GET /api/lists
```

**Description**: Retrieve all lists for the authenticated user.

**Response**:
```json
{
  "data": {
    "results": [
      {
        "id": 12345,
        "name": "My Watchlist",
        "description": "Movies to watch",
        "public": false,
        "item_count": 15
      }
    ],
    "total_results": 1
  },
  "status": "success"
}
```

#### Get Specific List
```
GET /api/lists/:tmdb_list_id
```

**Description**: Retrieve details of a specific TMDB list owned by the user.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Response**: Same as create list response with full list details

**Error Codes**:
- `401`: Authentication required
- `403`: Access denied (not list owner)
- `404`: List not found
- `500`: Server error

#### Update List
```
PUT /api/lists/:tmdb_list_id
```

**Description**: Update TMDB list details.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Request Body**:
```json
{
  "name": "Updated List Name",
  "description": "Updated description",
  "public": true
}
```

**Response**: Updated list data

**Error Codes**:
- `400`: Invalid request data
- `401`: Authentication required
- `403`: Access denied
- `404`: List not found
- `422`: Validation errors
- `500`: Server error

#### Delete List
```
DELETE /api/lists/:tmdb_list_id
```

**Description**: Delete a TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Response**:
```json
{
  "status": "success",
  "message": "List deleted successfully"
}
```

**Error Codes**:
- `401`: Authentication required
- `403`: Access denied
- `404`: List not found
- `500`: Server error

#### Clear List
```
POST /api/lists/:tmdb_list_id/clear
```

**Description**: Remove all movies from a TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Response**:
```json
{
  "status": "success",
  "message": "List cleared successfully"
}
```

### Movie Management

#### Add Movie to List
```
POST /api/lists/:tmdb_list_id/movies
```

**Description**: Add a movie to a TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Request Body**:
```json
{
  "movie_id": 550
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Movie added to list successfully"
}
```

**Error Codes**:
- `400`: Invalid movie ID
- `401`: Authentication required
- `403`: Access denied
- `404`: List or movie not found
- `409`: Movie already in list
- `500`: Server error

#### Remove Movie from List
```
DELETE /api/lists/:tmdb_list_id/movies/:tmdb_movie_id
```

**Description**: Remove a movie from a TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID
- `tmdb_movie_id` (integer, required): TMDB movie ID

**Response**:
```json
{
  "status": "success",
  "message": "Movie removed from list successfully"
}
```

**Error Codes**:
- `401`: Authentication required
- `403`: Access denied
- `404`: List, movie, or list item not found
- `500`: Server error

### List Sharing & Privacy

#### Share List
```
POST /api/lists/:tmdb_list_id/share
```

**Description**: Generate sharing information for a TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Response**:
```json
{
  "data": {
    "public_url": "https://flixir.app/lists/public/12345",
    "shared_url": "https://flixir.app/lists/shared/12345",
    "tmdb_url": "https://www.themoviedb.org/list/12345"
  },
  "status": "success"
}
```

#### Update Privacy Settings
```
POST /api/lists/:tmdb_list_id/privacy
```

**Description**: Update privacy settings for a TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Request Body**:
```json
{
  "public": true
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Privacy settings updated successfully"
}
```

### Synchronization Operations

#### Sync All Lists
```
POST /api/lists/sync
```

**Description**: Synchronize all user's TMDB lists with the local cache.

**Response**:
```json
{
  "data": {
    "synced_lists": 5,
    "sync_time": "2024-01-15T10:30:00Z"
  },
  "status": "success",
  "message": "All lists synchronized successfully"
}
```

#### Sync Specific List
```
POST /api/lists/:tmdb_list_id/sync
```

**Description**: Synchronize a specific TMDB list.

**Parameters**:
- `tmdb_list_id` (integer, required): TMDB list ID

**Response**:
```json
{
  "data": {
    "list_id": 12345,
    "sync_time": "2024-01-15T10:30:00Z",
    "items_synced": 25
  },
  "status": "success",
  "message": "List synchronized successfully"
}
```

#### Get Sync Status
```
GET /api/lists/sync/status
```

**Description**: Get synchronization status for all user's lists.

**Response**:
```json
{
  "data": {
    "last_sync": "2024-01-15T10:30:00Z",
    "sync_in_progress": false,
    "lists_status": [
      {
        "list_id": 12345,
        "status": "synced",
        "last_sync": "2024-01-15T10:30:00Z"
      }
    ]
  },
  "status": "success"
}
```

### Queue Management

#### Get Queue Status
```
GET /api/lists/queue
```

**Description**: Get all queued operations for the authenticated user.

**Response**:
```json
{
  "data": {
    "operations": [
      {
        "id": "uuid-123",
        "operation_type": "add_movie",
        "list_id": 12345,
        "status": "pending",
        "retry_count": 0,
        "created_at": "2024-01-15T10:30:00Z"
      }
    ],
    "stats": {
      "pending": 2,
      "processing": 0,
      "failed": 1,
      "completed": 10
    }
  },
  "status": "success"
}
```

#### Retry All Failed Operations
```
POST /api/lists/queue/retry
```

**Description**: Retry all failed operations for the authenticated user.

**Response**:
```json
{
  "data": {
    "retried_operations": 3
  },
  "status": "success",
  "message": "Failed operations queued for retry"
}
```

#### Retry Specific Operation
```
POST /api/lists/queue/:operation_id/retry
```

**Description**: Retry a specific failed operation.

**Parameters**:
- `operation_id` (uuid, required): Operation ID

**Response**:
```json
{
  "status": "success",
  "message": "Operation queued for retry"
}
```

#### Cancel Operation
```
DELETE /api/lists/queue/:operation_id
```

**Description**: Cancel a pending operation.

**Parameters**:
- `operation_id` (uuid, required): Operation ID

**Response**:
```json
{
  "status": "success",
  "message": "Operation cancelled successfully"
}
```

#### Get Queue Statistics
```
GET /api/lists/queue/stats
```

**Description**: Get queue statistics for the authenticated user.

**Response**:
```json
{
  "data": {
    "pending": 2,
    "processing": 1,
    "completed": 50,
    "failed": 3,
    "cancelled": 1,
    "total": 57
  },
  "status": "success"
}
```

## Error Handling

### Common Error Codes

- `400 Bad Request`: Invalid request data or parameters
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Access denied (insufficient permissions)
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource conflict (e.g., duplicate movie in list)
- `422 Unprocessable Entity`: Validation errors
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error
- `503 Service Unavailable`: TMDB API unavailable

### Error Response Details

Error responses include detailed information to help with debugging:

```json
{
  "error": "validation_error",
  "message": "The provided data is invalid",
  "details": {
    "name": ["can't be blank"],
    "description": ["is too long (maximum is 500 characters)"]
  },
  "request_id": "req_123456789"
}
```

### Rate Limiting

The API respects TMDB's rate limits and implements intelligent retry logic:
- Automatic retry with exponential backoff for rate-limited requests
- Queue system for operations when API is temporarily unavailable
- Cache-first approach to reduce API calls

## Movie Details Integration

The TMDB Lists API is seamlessly integrated into movie detail pages, providing users with the ability to manage their lists directly from the movie viewing experience.

### Features

- **Real-time List Membership**: Movie detail pages display which lists contain the current movie
- **Quick Add Interface**: Modal selector for adding movies to existing lists
- **Optimistic Updates**: Immediate UI feedback with automatic rollback on failures
- **List Status Indicators**: Visual feedback for pending operations and sync status

### Integration Points

The movie details page (`/media/movie/:id`) integrates with the following API endpoints:

1. **Get User Lists**: Automatically loads user's lists to display membership status
2. **Add Movie to List**: Provides quick-add functionality via modal interface
3. **Remove Movie from List**: Allows removal directly from the movie page
4. **Check Movie Membership**: Displays real-time membership status for all user lists

### User Experience Flow

1. User navigates to a movie detail page
2. If authenticated, the page loads user's TMDB lists
3. Movie membership status is displayed for each list
4. User can add/remove the movie from lists with immediate visual feedback
5. Operations are queued if TMDB API is temporarily unavailable
6. Success/error messages provide clear feedback on operation status

### Technical Implementation

The integration uses Phoenix LiveView for real-time updates and the following components:

- **MovieDetailsLive**: Main LiveView module handling movie details and list integration
- **UserMovieListComponents**: Reusable UI components for list management
- **Lists Context**: Backend API for TMDB list operations
- **Queue System**: Offline support and retry logic for failed operations

## SDK and Integration

### cURL Examples

**Create a list:**
```bash
curl -X POST "https://flixir.app/api/lists" \
  -H "Content-Type: application/json" \
  -H "Cookie: _flixir_key=session_cookie" \
  -d '{
    "name": "My Watchlist",
    "description": "Movies I want to watch",
    "public": false
  }'
```

**Add movie to list:**
```bash
curl -X POST "https://flixir.app/api/lists/12345/movies" \
  -H "Content-Type: application/json" \
  -H "Cookie: _flixir_key=session_cookie" \
  -d '{"movie_id": 550}'
```

### JavaScript Example

```javascript
// Create a new list
const response = await fetch('/api/lists', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  credentials: 'include', // Include session cookie
  body: JSON.stringify({
    name: 'My Watchlist',
    description: 'Movies I want to watch',
    public: false
  })
});

const result = await response.json();
if (result.status === 'success') {
  console.log('List created:', result.data);
} else {
  console.error('Error:', result.message);
}
```

## Webhooks and Real-time Updates

Currently, the API does not support webhooks, but real-time updates are available through the web interface using Phoenix LiveView. Future versions may include webhook support for external integrations.

## Versioning

The current API version is v1 (implicit). Future versions will be explicitly versioned in the URL path (e.g., `/api/v2/lists`).