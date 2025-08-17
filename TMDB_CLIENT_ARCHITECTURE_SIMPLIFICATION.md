# TMDB Client Architecture Simplification

## Summary

Simplified the `Flixir.Lists.TMDBClient` module by reverting from a flexible path-based URL building system back to a unified base URL approach for all TMDB API operations.

## Changes Made

### 1. Removed Function: `get_base_url_for_path/1`

Removed the path-aware base URL selection function that was previously added for flexibility:

```elixir
# REMOVED:
defp get_base_url_for_path(path) do
  case path do
    _ -> get_base_url()
  end
end
```

### 2. Simplified `build_url/2` Function

Reverted the `build_url/2` function to use the standard base URL approach:

```elixir
# BEFORE:
defp build_url(path, params) do
  base_url = get_base_url_for_path(path)  # Path-based selection
  # ...
end

# AFTER:
defp build_url(path, params) do
  base_url = get_base_url()  # Unified base URL
  # ...
end
```

### 3. Updated Module Documentation

Simplified the module documentation to reflect the unified architecture:

```elixir
@moduledoc """
HTTP client for TMDB Lists API operations.

## Architecture

The client uses a unified base URL for all TMDB API operations, providing
a simple and consistent approach to URL building across all endpoints.
"""
```

## Rationale

The path-based URL building system was removed for the following reasons:

1. **Simplicity**: The current implementation only uses a single TMDB API base URL
2. **YAGNI Principle**: The flexibility was not currently needed and added unnecessary complexity
3. **Maintainability**: Simpler code is easier to understand and maintain
4. **Performance**: Eliminates an unnecessary function call in the URL building process

## Benefits

1. **Reduced Complexity**: Simpler, more straightforward URL building logic
2. **Better Performance**: One less function call per API request
3. **Easier Testing**: Fewer code paths to test and maintain
4. **Clearer Intent**: The code now clearly shows it uses a single base URL

## Impact

- **No Breaking Changes**: All existing functionality remains the same
- **Test Coverage**: All existing tests continue to pass without modification
- **Performance**: Slight improvement due to reduced function call overhead
- **Maintainability**: Improved code readability and reduced complexity

## Future Considerations

If path-based URL selection becomes necessary in the future, it can be easily re-implemented. The current approach provides a solid foundation that can be extended when actual requirements emerge.

## Files Modified

- `lib/flixir/lists/tmdb_client.ex` - Simplified URL building logic
- `CLAUDE.md` - Updated documentation to reflect unified architecture
- `TMDB_CLIENT_ARCHITECTURE_SIMPLIFICATION.md` - This documentation file

## Testing

All existing tests pass without modification, confirming backward compatibility:

```bash
mix test test/flixir/lists/tmdb_client_test.exs
# All tests pass
```

## Related Documentation

- `TMDB_CLIENT_ARCHITECTURE_UPDATE.md` - Previous architectural change (now superseded)
- `docs/api_endpoints.md` - API endpoint documentation
- `CLAUDE.md` - Comprehensive system documentation