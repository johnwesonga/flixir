# Queue System for TMDB List Operations

The queue system provides offline support and reliable operation processing for TMDB list operations. When the TMDB API is unavailable or operations fail, they are queued for later retry with exponential backoff.

## Components

### 1. QueuedOperation Schema
- Stores operations that need to be processed
- Tracks retry attempts and status
- Supports operation deduplication

### 2. Queue Module
- Main interface for queue operations
- Handles operation enqueueing and processing
- Provides monitoring and statistics

### 3. QueueProcessor GenServer
- Background processor for queued operations
- Runs periodically to process pending operations
- Handles cleanup of old operations

## Usage

### Enqueuing Operations

```elixir
# Create a list operation
{:ok, operation} = Flixir.Lists.Queue.enqueue_operation(
  "create_list",
  tmdb_user_id,
  nil,
  %{"name" => "My New List", "description" => "Description"}
)

# Add movie to list operation
{:ok, operation} = Flixir.Lists.Queue.enqueue_operation(
  "add_movie",
  tmdb_user_id,
  tmdb_list_id,
  %{"movie_id" => 12345}
)
```

### Processing Operations

Operations are automatically processed by the QueueProcessor, but you can also process them manually:

```elixir
# Process a specific operation
{:ok, result} = Flixir.Lists.Queue.process_operation(operation)

# Process all pending operations
Flixir.Lists.Queue.process_pending_operations()

# Process all pending operations for a specific user
Flixir.Lists.Queue.process_user_operations(tmdb_user_id)
```

### Monitoring

```elixir
# Get queue statistics
stats = Flixir.Lists.Queue.get_queue_stats()
# Returns: %{pending: 5, processing: 1, completed: 100, failed: 2, total: 108}

# Get pending operations for a user
operations = Flixir.Lists.Queue.get_user_pending_operations(tmdb_user_id)

# Get failed operations that can be retried
failed_ops = Flixir.Lists.Queue.get_failed_operations()
```

### Manual Retry

```elixir
# Retry a failed operation
{:ok, result} = Flixir.Lists.Queue.retry_operation(operation_id)

# Cancel a pending operation
{:ok, cancelled_op} = Flixir.Lists.Queue.cancel_operation(operation_id)
```

## Operation Types

The queue supports the following operation types:

- `create_list` - Create a new TMDB list
- `update_list` - Update list metadata
- `delete_list` - Delete a TMDB list
- `clear_list` - Remove all movies from a list
- `add_movie` - Add a movie to a list
- `remove_movie` - Remove a movie from a list

## Error Handling

The queue system implements several error handling strategies:

### Retry Logic
- Failed operations are automatically retried up to 5 times
- Uses exponential backoff (30s, 60s, 120s, 240s, 480s)
- Maximum delay is capped at 1 hour

### Operation Deduplication
- Prevents duplicate operations for the same user/list/movie combination
- Reduces unnecessary API calls and conflicts

### Status Tracking
Operations have the following statuses:
- `pending` - Waiting to be processed
- `processing` - Currently being processed
- `completed` - Successfully completed
- `failed` - Failed after max retries
- `cancelled` - Manually cancelled

## Background Processing

The QueueProcessor runs automatically and:
- Processes pending operations every minute
- Cleans up old completed/cancelled operations daily
- Provides status monitoring and control

### Controlling the Processor

```elixir
# Get processor status
status = Flixir.Lists.QueueProcessor.get_status()

# Enable/disable processing
Flixir.Lists.QueueProcessor.set_enabled(false)

# Manually trigger processing
Flixir.Lists.QueueProcessor.process_now()
```

## Database Schema

The queue uses a single table `queued_list_operations` with the following structure:

```sql
CREATE TABLE queued_list_operations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_type VARCHAR(255) NOT NULL,
  tmdb_user_id INTEGER NOT NULL,
  tmdb_list_id INTEGER,
  operation_data JSONB NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_retry_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(255) DEFAULT 'pending',
  error_message TEXT,
  scheduled_for TIMESTAMP WITH TIME ZONE,
  inserted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for efficient queue processing
CREATE INDEX idx_queued_operations_status_inserted ON queued_list_operations (status, inserted_at);
CREATE INDEX idx_queued_operations_user_id ON queued_list_operations (tmdb_user_id);
CREATE INDEX idx_queued_operations_scheduled_for ON queued_list_operations (scheduled_for);
CREATE INDEX idx_queued_operations_type_list_status ON queued_list_operations (operation_type, tmdb_list_id, status);
```

### Schema Details

- **id**: UUID primary key with automatic generation
- **operation_type**: Type of operation (create_list, add_movie, etc.)
- **tmdb_user_id**: TMDB user ID for operation ownership
- **tmdb_list_id**: Target list ID (nullable for list creation operations)
- **operation_data**: JSON data containing operation parameters
- **retry_count**: Number of retry attempts (default 0)
- **last_retry_at**: Timestamp of last retry attempt
- **status**: Current operation status (pending, processing, completed, failed, cancelled)
- **error_message**: Error details for failed operations
- **scheduled_for**: When the operation should be processed (for delayed operations)
- **inserted_at/updated_at**: Standard timestamps with timezone support

### Index Strategy

The indexes are optimized for common queue operations:
- **Status + Inserted**: Efficient retrieval of pending operations in chronological order
- **User ID**: Fast lookup of user-specific operations
- **Scheduled For**: Efficient processing of scheduled operations
- **Type + List + Status**: Complex queries for specific operation types and statuses

## Integration with Lists Context

The queue system is integrated with the main Lists context to provide seamless offline support:

```elixir
# When TMDB API is available
{:ok, list} = Flixir.Lists.create_list(user_id, attrs)

# When TMDB API is unavailable
{:ok, :queued} = Flixir.Lists.create_list(user_id, attrs)
# Operation is queued and will be processed when API is available
```

This ensures that users can continue using the application even when the TMDB API is temporarily unavailable.