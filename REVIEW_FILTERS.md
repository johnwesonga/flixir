# ReviewFilters Component Documentation

## Overview

The `FlixirWeb.ReviewFilters` component provides a comprehensive filtering and sorting interface for movie and TV show reviews. It offers real-time filtering capabilities with visual feedback and an intuitive user experience. The component uses proper Phoenix LiveView form handling for optimal performance and accessibility.

## Features

### Core Functionality
- **Multi-criteria Filtering**: Filter reviews by rating, author, and content
- **Flexible Sorting**: Sort by date, rating, or author with customizable order
- **Real-time Updates**: Live filtering without page reloads
- **Visual Feedback**: Active filter indicators and result counts
- **Responsive Design**: Mobile-first design with adaptive layouts

### Filter Types

#### 1. Sort Control
```elixir
<.sort_control
  current_sort={:date}
  current_order={:desc}
  on_change="update_filters"
/>
```

**Options:**
- `:date` - Sort by review creation date
- `:rating` - Sort by review rating
- `:author` - Sort by author name alphabetically

**Sort Orders:**
- `:desc` - Descending order (newest first, highest rating first)
- `:asc` - Ascending order (oldest first, lowest rating first)

#### 2. Rating Filter
```elixir
<.rating_filter
  current_filter={:positive}
  on_change="update_filters"
/>
```

**Filter Options:**
- `nil` - Show all ratings
- `:positive` - Reviews with 6+ star ratings
- `:negative` - Reviews with < 6 star ratings
- `{8, 10}` - High ratings (8-10 stars)
- `{5, 7}` - Medium ratings (5-7 stars)
- `{1, 4}` - Low ratings (1-4 stars)

#### 3. Author Filter
```elixir
<.author_filter
  current_filter="john"
  on_change="update_filters"
/>
```

- Text input with debounced search (300ms delay)
- Case-insensitive partial matching
- Clear button for active filters

#### 4. Content Filter
```elixir
<.content_filter
  current_filter="great movie"
  on_change="update_filters"
/>
```

- Full-text search within review content
- Debounced input for performance
- Case-insensitive matching

## Usage Example

### Basic Implementation

```elixir
# In your LiveView
def render(assigns) do
  ~H"""
  <.review_filters
    filters={@filters}
    on_filter_change="update_review_filters"
    total_reviews={length(@all_reviews)}
    filtered_count={length(@filtered_reviews)}
  />
  """
end

# Handle filter changes
def handle_event("update_review_filters", params, socket) do
  updated_filters = process_filter_params(params, socket.assigns.filters)
  filtered_reviews = apply_filters(socket.assigns.all_reviews, updated_filters)
  
  socket = 
    socket
    |> assign(:filters, updated_filters)
    |> assign(:filtered_reviews, filtered_reviews)
    
  {:noreply, socket}
end
```

### Filter State Management

The component expects a filter map with the following structure:

```elixir
%{
  sort_by: :date,           # :date | :rating | :author
  sort_order: :desc,        # :desc | :asc
  filter_by_rating: nil,    # nil | :positive | :negative | {min, max}
  author_filter: nil,       # nil | string
  content_filter: nil       # nil | string
}
```

## Event Handling

The component emits events with specific actions:

### Sort Events
- `phx-value-action="sort"` - Sort field changed
- `phx-value-action="toggle_sort_order"` - Sort order toggled

### Filter Events
- `phx-value-action="filter_rating"` - Rating filter changed
- `phx-value-action="filter_author"` - Author filter changed
- `phx-value-action="filter_content"` - Content filter changed

### Clear Events
- `phx-value-action="clear_all"` - Clear all filters
- `phx-value-action="clear_author"` - Clear author filter
- `phx-value-action="clear_content"` - Clear content filter
- `phx-value-action="clear_rating"` - Clear rating filter
- `phx-value-action="clear_sort"` - Reset sort to defaults

## Styling and Customization

### CSS Classes
The component uses Tailwind CSS classes and can be customized:

```elixir
<.review_filters
  class="custom-filter-styles"
  id="movie-review-filters"
  # ... other props
/>
```

### Test Attributes
All interactive elements include `data-testid` attributes for testing:

- `data-testid="review-filters"` - Main container
- `data-testid="sort-by-select"` - Sort dropdown
- `data-testid="sort-order-toggle"` - Sort order button
- `data-testid="rating-filter-select"` - Rating filter dropdown
- `data-testid="author-filter-input"` - Author search input
- `data-testid="content-filter-input"` - Content search input
- `data-testid="clear-all-filters"` - Clear all button
- `data-testid="remove-filter-{action}"` - Individual filter remove buttons

## Performance Considerations

### Debouncing
Text inputs use `phx-debounce="300"` to prevent excessive server requests during typing.

### Filter State
The component tracks active filters efficiently:
- Counts active filters for UI indicators
- Builds filter tags only when needed
- Minimizes re-renders through proper state management

### Memory Usage
- Filter state is kept minimal
- No unnecessary data duplication
- Efficient string operations for text filters

## Integration with Reviews Context

The component is designed to work with the `Flixir.Reviews` context:

```elixir
# Apply filters using the Reviews context
def apply_review_filters(reviews, filters) do
  reviews
  |> Flixir.Reviews.filter_reviews(filters)
  |> Flixir.Reviews.sort_reviews(
      Map.get(filters, :sort_by, :date),
      Map.get(filters, :sort_order, :desc)
    )
end
```

## Accessibility

The component includes accessibility features:
- Proper ARIA labels for form controls
- Keyboard navigation support
- Screen reader friendly text
- Focus management for interactive elements

## Testing

Test the component using the provided test attributes:

```elixir
test "filters reviews by rating", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/movie/123/reviews")
  
  view
  |> element("[data-testid='rating-filter-select']")
  |> render_change(%{"filter_by_rating" => "positive"})
  
  assert has_element?(view, "[data-testid='remove-filter-clear_rating']")
end
```

## Future Enhancements

Potential improvements for the component:
- Date range filtering for review creation dates
- Advanced rating filters (e.g., rating by specific sources)
- Saved filter presets
- Export filtered results
- Bulk operations on filtered reviews

## Dependencies

The component depends on:
- `Phoenix.Component` - Core component functionality
- `Phoenix.LiveView.JS` - Client-side interactions
- `FlixirWeb.CoreComponents` - Icon and button components
- `FlixirWeb.Gettext` - Internationalization support

## Browser Support

The component works in all modern browsers and includes:
- Progressive enhancement
- Graceful degradation for older browsers
- Mobile-responsive design
- Touch-friendly interactions