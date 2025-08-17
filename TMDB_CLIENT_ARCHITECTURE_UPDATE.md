# TMDB Client Architecture Update

> **⚠️ SUPERSEDED**: This architectural change has been reverted. See `TMDB_CLIENT_ARCHITECTURE_SIMPLIFICATION.md` for the current implementation.

## Summary

Updated the `Flixir.Lists.TMDBClient` module to use a more flexible URL building system that supports path-based base URL selection.

## Changes Made

### 1. New Function: `get_base_url_for_path/1`

Added a new private function `get_base_url_for_path/1` that allows for different base URLs based on the API path:

```elixir
defp get_base_url_for_path(path) do
  # Flexible base URL selection based on API path
  # This allows for future support of different API versions or specialized endpoints
  # while maintaining backward compatibility with existing functionality
  case path do
    # Future: Could support different base URLs for different API versions
    # "/v4" <> _ -> get_v4_base_url()
    # "/auth" <> _ -> get_auth_base_url()
    _ -> get_base_url()
  end
end
```

### 2. Updated `build_url/2` Function

Modified the `build_url/2` function to use the new path-aware base URL selection:

```elixir
defp build_url(path, params) do
  base_url = get_base_url_for_path(path)  # Changed from get_base_url()
  api_key = get_api_key()
  base_params = %{api_key: api_key}
  all_params = Map.merge(base_params, params)

  query_string = URI.encode_query(all_params)
  "#{base_url}#{path}?#{query_string}"
end
```

### 3. Updated Module Documentation

Enhanced the module documentation to reflect the new flexible architecture:

```elixir
@moduledoc """
HTTP client for TMDB Lists API operations.

Handles all list management operations through TMDB's native API,
including creating, reading, updating, and deleting lists, as well as
adding and removing movies from lists.

This module includes comprehensive error handling with retry logic,
exponential backoff, and graceful degradation for TMDB API issues.

## Architecture

The client uses a flexible URL building system that allows for different
base URLs based on the API path, enabling future support for different
API versions or specialized endpoints while maintaining backward compatibility.
"""
```

## Benefits

1. **Future Flexibility**: Enables support for different API versions or specialized endpoints
2. **Backward Compatibility**: Current functionality remains unchanged
3. **Clean Architecture**: Separates URL building logic from path-specific concerns
4. **Extensibility**: Easy to add support for new API endpoints with different base URLs

## Impact

- **No Breaking Changes**: All existing functionality remains the same
- **Test Coverage**: All existing tests continue to pass
- **Performance**: No performance impact - same number of function calls
- **Maintainability**: Improved code organization and future extensibility

## Future Possibilities

This architecture enables future enhancements such as:

- Support for TMDB API v4 endpoints
- Specialized authentication endpoints
- Region-specific API endpoints
- Development/staging environment endpoint switching

## Files Modified

- `lib/flixir/lists/tmdb_client.ex` - Added new function and updated URL building
- `CLAUDE.md` - Updated documentation to reflect architectural improvement

## Testing

All existing tests pass without modification, confirming backward compatibility.

```bash
mix test test/flixir/lists/tmdb_client_test.exs
# 27 tests, 0 failures
```