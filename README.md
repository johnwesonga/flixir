# Flixir

A Phoenix LiveView web application for discovering movies and TV shows, powered by The Movie Database (TMDB) API. Built using [Kiro](https://kiro.dev/blog/introducing-kiro/) for enhanced development experience.

## Features

### 🎬 Movie & TV Show Discovery
- **Search**: Real-time search across movies and TV shows
- **Filtering**: Filter results by media type (movies, TV shows, or all)
- **Sorting**: Sort by relevance, popularity, release date, or title
- **Navigation**: Click any search result to view detailed information and reviews
- **Detail Pages**: Dedicated pages for each movie and TV show with comprehensive information
- **Caching**: Intelligent caching system for improved performance

### ⭐ Reviews & Ratings System
- **Review Display**: Rich review cards with expandable content
- **Rating Statistics**: Comprehensive rating breakdowns and averages
- **Spoiler Protection**: Automatic spoiler detection and warnings
- **Interactive Elements**: Expandable reviews with "read more" functionality
- **Multi-source Support**: Aggregated ratings from multiple sources
- **Advanced Filtering**: Filter reviews by rating ranges, author names, and content keywords
- **Smart Sorting**: Sort reviews by date, rating, or author with ascending/descending options
- **Real-time Updates**: Live filtering and sorting without page reloads

### 🚀 Performance & UX
- **Real-time Updates**: Phoenix LiveView for seamless interactions
- **Responsive Design**: Tailwind CSS for mobile-first design
- **Error Handling**: Graceful error handling with retry mechanisms
- **Loading States**: Smooth loading indicators and transitions
- **Error Recovery**: One-click retry functionality for failed operations

## Getting Started

### Prerequisites
- Elixir ~> 1.15
- Phoenix ~> 1.8.0
- PostgreSQL
- TMDB API Key

### Installation

1. Clone the repository and install dependencies:
   ```bash
   mix setup
   ```

2. Configure your TMDB API key in `config/dev.exs`:
   ```elixir
   config :flixir, :tmdb,
     api_key: "your_tmdb_api_key_here"
   ```

3. Start the Phoenix server:
   ```bash
   mix phx.server
   ```
   
   Or with interactive shell:
   ```bash
   iex -S mix phx.server
   ```

4. Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Architecture

### Core Modules

#### Media Context (`lib/flixir/media/`)
- **SearchResult**: Data structure for search results
- **TMDBClient**: API client for The Movie Database
- **Cache**: High-performance caching layer

#### Reviews Context (`lib/flixir/reviews/`)
- **Review**: Individual review data structure
- **RatingStats**: Aggregated rating statistics
- **Cache**: Review-specific caching system
- **TMDBClient**: Review-focused API operations

#### Web Components (`lib/flixir_web/components/`)
- **SearchComponents**: Interactive search interface with clickable result cards
- **ReviewComponents**: Review cards, rating displays, and interactive elements
- **ReviewFilters**: Advanced filtering and sorting controls for reviews

#### LiveView Modules (`lib/flixir_web/live/`)
- **SearchLive**: Real-time search interface with filtering and sorting
- **MovieDetailsLive**: Movie and TV show detail pages with review management and error recovery
  - Handles dynamic routing for both movies and TV shows
  - Converts string media types from URL parameters to atoms for API compatibility
  - Provides comprehensive error handling and retry functionality for failed operations

#### Routing & Navigation (`lib/flixir_web/router.ex`)
- **Home Route**: `/` - Landing page with HTTP GET route to SearchLive for immediate search functionality
- **Search Route**: `/search` - Main search interface with LiveView and URL parameter support
- **Detail Routes**: `/:type/:id` - Dynamic LiveView routes for movie and TV show details
- **URL Parameters**: Shareable search states with query, filter, and sort parameters
- **Mixed Navigation**: Combines HTTP GET routes and LiveView for optimal performance and user experience

### Key Features Implementation

#### Review System
The review system provides comprehensive review management with:

- **Review Cards**: Interactive cards with expandable content, spoiler warnings, and author information
- **Rating Statistics**: Visual rating breakdowns with percentage distributions
- **Caching**: Intelligent caching for both individual reviews and aggregated statistics
- **Advanced Filtering & Sorting**: Comprehensive filtering and sorting system with real-time updates

##### Review Filtering & Sorting Features
The `ReviewFilters` component provides powerful filtering capabilities:

**Sorting Options:**
- Sort by date, rating, or author name
- Toggle between ascending and descending order
- Visual indicators for active sort settings

**Rating Filters:**
- Filter by positive reviews (6+ stars) or negative reviews (< 6 stars)
- Custom rating ranges: High (8-10), Medium (5-7), Low (1-4)
- Support for all ratings or specific rating criteria

**Content Filters:**
- Search within review content using keywords
- Filter by author name with partial matching
- Real-time filtering with debounced input for performance

**Interactive Features:**
- Active filter badges with one-click removal
- Clear all filters functionality
- Live count of filtered vs. total reviews
- Responsive design for mobile and desktop

Recent improvements include enhanced rating breakdown display logic that ensures rating distributions are only shown when there are actual reviews with ratings available.

#### Search & Discovery
- **Real-time Search**: Debounced search with instant results
- **Interactive Results**: Clickable search result cards that navigate to detail pages
- **Advanced Filtering**: Filter by media type with visual indicators
- **Smart Sorting**: Multiple sorting options with URL persistence
- **Shareable URLs**: Query parameters for bookmarkable search states
- **Responsive Design**: Optimized grid layout for all screen sizes
- **Loading States**: Skeleton cards and smooth transitions during search
- **Empty States**: Helpful suggestions when no results are found

#### Error Handling & Recovery
The application provides robust error handling with user-friendly recovery options:

**Error Types Handled:**
- Network timeouts and connection failures
- API rate limiting and authentication errors
- Service unavailability and server errors
- Data transformation and parsing errors

**Recovery Mechanisms:**
- **Retry Functionality**: One-click retry buttons for failed operations
- **Graceful Degradation**: Partial functionality when some services fail
- **User Feedback**: Clear error messages with actionable guidance
- **State Preservation**: Maintains user context during error recovery

**Implementation Details:**
- The `MovieDetailsLive` module includes a `retry_reviews` event handler
- Error states are clearly displayed with contextual retry options
- Loading states prevent duplicate requests during recovery
- Error messages are formatted for user comprehension

## Configuration

### Environment Variables
```bash
# Required
TMDB_API_KEY=your_api_key_here

# Optional
DATABASE_URL=postgres://user:pass@localhost/flixir_dev
SECRET_KEY_BASE=your_secret_key_base
```

### TMDB Configuration
Configure in `config/config.exs`:
```elixir
config :flixir, :tmdb,
  api_key: System.get_env("TMDB_API_KEY"),
  base_url: "https://api.themoviedb.org/3",
  timeout: 5_000,
  max_retries: 3
```

## Testing

Run the full test suite:
```bash
mix test
```

Run tests with coverage:
```bash
mix test --cover
```

The application includes comprehensive test coverage for:
- Unit tests for all contexts and modules
- Integration tests for complete user workflows
- Performance benchmarks and load testing
- Error handling and edge cases
- Mock testing for external API dependencies and context functions

### Test Architecture

The test suite uses comprehensive mocking strategies to ensure reliable and fast tests:

**Reviews Context Testing:**
- All Reviews context functions are properly mocked in LiveView tests
- `filter_reviews/2` function is mocked to test filtering behavior without dependencies
- `get_reviews/3`, `get_rating_stats/2`, and other context functions have dedicated mocks
- Test mocks simulate real filtering, sorting, and pagination logic for accurate behavior testing

**LiveView Integration Tests:**
- MovieDetailsLive tests include complete mocking of the Reviews context
- Tests verify proper integration between LiveView and context layers
- Mock functions return realistic data structures matching production behavior

## Development

### Code Quality
```bash
# Format code
mix format

# Check formatting
mix format --check-formatted
```

### Database Operations
```bash
# Reset database
mix ecto.reset

# Create migration
mix ecto.gen.migration migration_name

# Run migrations
mix ecto.migrate
```

### Asset Management
```bash
# Build assets for development
mix assets.build

# Build and minify for production
mix assets.deploy
```

## Deployment

Ready to run in production? Please check the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

### Production Configuration
Ensure the following environment variables are set:
- `TMDB_API_KEY`
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `PHX_HOST`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run the test suite
5. Submit a pull request

## Learn More

### Phoenix Framework
* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

### TMDB API
* Documentation: https://developers.themoviedb.org/3
* API Reference: https://developers.themoviedb.org/3/getting-started

### Kiro Development Tool
* Blog: https://kiro.dev/blog/introducing-kiro/
