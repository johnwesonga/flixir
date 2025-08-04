# Implementation Plan

- [x] 1. Create database migrations for user movie lists
  - Create migration for `user_movie_lists` table with name, description, privacy, and user association
  - Create migration for `user_movie_list_items` junction table with list and movie relationships
  - Add appropriate indexes for performance and unique constraints to prevent duplicate movies per list
  - _Requirements: 1.1, 2.1, 5.1, 9.1_

- [ ] 2. Implement Ecto schemas for user movie lists
  - Create `Flixir.Lists.UserMovieList` schema with validations for name length, description, and privacy settings
  - Create `Flixir.Lists.UserMovieListItem` schema with movie and list associations
  - Implement changeset functions with proper validation rules and constraint handling
  - Add associations between schemas for efficient data loading
  - _Requirements: 1.2, 1.6, 2.2, 2.6, 5.3, 9.1_

- [ ] 3. Create Lists context with core CRUD operations
  - Implement `Flixir.Lists` context module with functions for creating, reading, updating, and deleting lists
  - Add user authorization checks to ensure users can only access their own lists
  - Implement list statistics and summary functions for displaying list metadata
  - Add error handling and logging for database operations
  - _Requirements: 1.1, 1.5, 2.1, 2.5, 3.1, 3.5, 7.1, 7.2, 7.3, 7.4, 9.2, 9.5, 9.6_

- [ ] 4. Implement movie management functions in Lists context
  - Add functions for adding movies to lists with duplicate prevention
  - Implement movie removal from lists with proper authorization
  - Create functions to retrieve movies in a list with TMDB data integration
  - Add list clearing functionality that removes all movies while preserving list metadata
  - _Requirements: 4.1, 4.4, 4.5, 5.1, 5.3, 5.4, 5.6, 6.1, 6.3, 6.4, 6.6_

- [ ] 5. Create user movie lists UI components
  - Implement `FlixirWeb.UserMovieListComponents` with reusable components for list display and management
  - Create list card component showing name, description, movie count, and privacy status
  - Build list form component for creating and editing lists with validation feedback
  - Add confirmation modals for destructive operations like delete and clear
  - _Requirements: 1.1, 1.6, 2.1, 2.6, 3.2, 3.4, 4.2, 4.4, 7.1, 7.2, 8.1, 8.2, 8.4_

- [ ] 6. Implement UserMovieListsLive for lists overview
  - Create `FlixirWeb.UserMovieListsLive` LiveView for displaying all user lists
  - Handle mount with authentication checks and user data loading
  - Implement events for creating, editing, deleting, and clearing lists
  - Add real-time updates and error handling with user feedback
  - _Requirements: 1.1, 1.5, 2.1, 2.5, 3.1, 3.4, 4.1, 4.4, 7.5, 8.1, 8.3, 8.5, 9.2_

- [ ] 7. Create UserMovieListLive for individual list management
  - Implement `FlixirWeb.UserMovieListLive` for viewing and managing a single list
  - Add movie display with integration to TMDB data through Media context
  - Handle adding and removing movies from the list with optimistic updates
  - Implement list editing functionality and statistics display
  - _Requirements: 2.1, 2.2, 2.5, 5.1, 5.4, 5.6, 6.1, 6.4, 6.6, 7.1, 7.2, 7.3, 7.4_

- [ ] 8. Add routing for user movie lists feature
  - Update `lib/flixir_web/router.ex` with authenticated routes for list management
  - Add routes for lists overview, individual list view, and list editing
  - Ensure all routes require authentication using existing auth plug
  - Add proper parameter validation and error handling
  - _Requirements: 8.1, 8.5, 9.2_

- [ ] 9. Enhance movie details page with list integration
  - Modify `FlixirWeb.MovieDetailsLive` to show "Add to List" functionality for authenticated users
  - Create dropdown/modal for selecting which list to add movie to
  - Display which lists already contain the current movie
  - Add quick remove functionality for movies already in lists
  - _Requirements: 5.1, 5.2, 5.4, 6.1, 6.4_

- [ ] 10. Create templates for user movie lists LiveViews
  - Build `user_movie_lists_live.html.heex` template for lists overview with responsive design
  - Create `user_movie_list_live.html.heex` template for individual list view
  - Implement proper loading states, error displays, and empty states
  - Add mobile-responsive layouts and touch-friendly interactions
  - _Requirements: 1.6, 2.6, 3.4, 4.4, 6.6, 7.5, 8.4, 8.6_

- [ ] 11. Write unit tests for Lists context
  - Create comprehensive tests in `test/flixir/lists_test.exs` for all context functions
  - Test CRUD operations, authorization checks, and error handling
  - Test movie management functions including duplicate prevention
  - Test statistics and summary functions with various data scenarios
  - _Requirements: 1.1, 1.5, 1.6, 2.1, 2.5, 2.6, 3.1, 3.4, 3.5, 4.1, 4.4, 4.5, 5.1, 5.3, 5.4, 6.1, 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 9.1, 9.2, 9.5, 9.6_

- [ ] 12. Write schema tests for user movie list models
  - Test `UserMovieList` schema validations and changesets in dedicated test file
  - Test `UserMovieListItem` schema with associations and constraints
  - Verify database constraints and unique indexes work correctly
  - Test edge cases and validation error scenarios
  - _Requirements: 1.2, 1.6, 2.2, 2.6, 5.3, 9.1_

- [ ] 13. Write LiveView tests for user movie lists
  - Create `test/flixir_web/live/user_movie_lists_live_test.exs` for lists overview functionality
  - Test authentication requirements and user data isolation
  - Test list creation, editing, deletion, and clearing workflows
  - Test error handling and user feedback scenarios
  - _Requirements: 1.1, 1.5, 1.6, 2.1, 2.5, 2.6, 3.1, 3.4, 3.5, 4.1, 4.4, 4.5, 7.5, 8.1, 8.5, 9.2_

- [ ] 14. Write component tests for user movie list UI
  - Test all components in `FlixirWeb.UserMovieListComponents` for proper rendering
  - Test form components with validation states and error display
  - Test modal components for confirmation dialogs
  - Test responsive behavior and accessibility features
  - _Requirements: 1.6, 2.6, 3.4, 4.4, 7.5, 8.4, 8.6_

- [ ] 15. Create integration tests for complete user workflows
  - Test end-to-end user journey from authentication to list management
  - Test movie addition from search results and movie details pages
  - Test privacy settings and data isolation between users
  - Test error recovery and data persistence across sessions
  - _Requirements: 5.1, 5.4, 6.1, 6.4, 8.1, 8.5, 9.2, 9.3, 9.4, 9.6_

- [ ] 16. Add navigation integration for user movie lists
  - Update main navigation to include "My Lists" link for authenticated users
  - Add proper active state highlighting when viewing lists section
  - Ensure navigation is responsive and accessible
  - Add list count badge or indicator in navigation when appropriate
  - _Requirements: 8.1, 8.6_