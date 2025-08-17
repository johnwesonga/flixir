# Development Guide

## Code Quality Standards

### Code Formatting

The Flixir codebase maintains high quality standards with consistent formatting across all files:

#### Elixir Code
- **Standard Formatting**: All Elixir code follows standard formatting with `mix format`
- **Consistent Style**: Function definitions, module organization, and documentation follow Phoenix conventions
- **Pattern Matching**: Clear and readable pattern matching with proper indentation

#### Phoenix Templates (HEEx)
- **Modern Syntax**: Updated to use modern Phoenix LiveView HEEx template syntax
- **Consistent Indentation**: Proper indentation for nested HTML elements and Phoenix components
- **Template Expressions**: Clean separation between HTML and Elixir expressions using `{}` syntax
- **Component Structure**: Well-organized component files with logical grouping and clear separation of concerns

#### Recent Formatting Improvements

The `user_movie_list_components.ex` file has been updated with comprehensive formatting improvements:

- **Template Syntax Updates**: Converted legacy `<%= %>` syntax to modern `{}` syntax where appropriate
- **HTML Attribute Formatting**: Multi-line attributes properly formatted for better readability
- **Comment Formatting**: Consistent comment indentation and spacing
- **Function Organization**: Better spacing and line breaks in function definitions
- **Code Structure**: Improved logical grouping of related code sections

### Code Quality Tools

```bash
# Format all Elixir code
mix format

# Check if code is properly formatted
mix format --check-formatted

# Run tests with coverage
mix test --cover

# Check for unused dependencies
mix deps.unlock --check-unused
```

### Development Best Practices

1. **Always format code** before committing changes
2. **Use consistent naming** following Elixir/Phoenix conventions
3. **Write comprehensive tests** for new functionality
4. **Document public functions** with proper @doc annotations
5. **Follow Phoenix patterns** for contexts, controllers, and LiveViews
6. **Use proper error handling** with consistent error formats
7. **Maintain test coverage** for critical functionality

### Component Development

When developing Phoenix LiveView components:

1. **Use modern HEEx syntax** for templates
2. **Organize attributes** with proper indentation for multi-line elements
3. **Group related functions** logically within component modules
4. **Include proper documentation** for component attributes and slots
5. **Test component rendering** with various data states
6. **Follow accessibility guidelines** with proper ARIA attributes

### Template Guidelines

- Use `{}` syntax for simple Elixir expressions in templates
- Maintain consistent indentation (2 spaces) for nested elements
- Group related HTML sections with clear comments
- Format multi-line attributes for better readability
- Use semantic HTML elements where appropriate
- Include proper data-testid attributes for testing

### Testing Standards

- Write comprehensive unit tests for all business logic
- Include integration tests for complete user workflows
- Test error scenarios and edge cases
- Use proper test data setup and cleanup
- Mock external API dependencies appropriately
- Maintain high test coverage for critical paths

## Architecture Patterns

### Context Pattern
Business logic is organized in contexts under `lib/flixir/`:
- `Flixir.Auth` - Authentication and session management
- `Flixir.Lists` - TMDB movie lists management
- `Flixir.Media` - Movie and TV show search functionality
- `Flixir.Reviews` - Review and rating systems

### Web Layer Separation
All web-related code is in `lib/flixir_web/`:
- Controllers handle HTTP requests and API endpoints
- LiveViews manage real-time user interfaces
- Components provide reusable UI elements
- Plugs handle cross-cutting concerns like authentication

#### LiveView Architecture Patterns
LiveView modules follow consistent import patterns for shared functionality:

**Standard LiveView Imports:**
```elixir
use FlixirWeb, :live_view
import FlixirWeb.AppLayout          # Application layout and navigation components
import FlixirWeb.CoreComponents     # Core UI components (buttons, forms, etc.)
import FlixirWeb.[Context]Components # Context-specific components
alias Flixir.[Context]              # Business logic contexts
```

**AppLayout Integration:**
All LiveView modules import `FlixirWeb.AppLayout` to access:
- `app_layout/1` component for consistent page structure
- Navigation helper functions (`movie_nav_items/0`, `review_nav_items/0`)
- Unified header, footer, and sub-navigation components
- Authentication state management across pages

This pattern ensures consistent UI structure and navigation behavior across all LiveView pages.

### Database Patterns
- Ecto schemas define data structures
- Changesets handle validation and data transformation
- Migrations manage database schema changes
- Proper indexing for performance optimization

## Performance Considerations

### Caching Strategy
- **ETS-based Lists Cache**: High-performance caching for TMDB list data
- **Media Cache**: In-memory caching for search results
- **Multi-layer Caching**: Different TTL values for different data types
- **Cache Invalidation**: Targeted invalidation to maintain data consistency

### Database Optimization
- Proper indexing on frequently queried columns
- Efficient query patterns with Ecto
- Connection pooling for concurrent requests
- Background cleanup processes for expired data

### API Integration
- Retry logic with exponential backoff for external APIs
- Rate limiting compliance with TMDB API guidelines
- Queue system for offline operation support
- Optimistic updates for better user experience