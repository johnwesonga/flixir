# Technology Stack

## Core Technologies
- **Language**: Elixir ~> 1.15
- **Framework**: Phoenix ~> 1.8.0
- **Database**: PostgreSQL with Ecto SQL
- **Web Server**: Bandit (Phoenix adapter)
- **Frontend**: Phoenix LiveView with server-side rendering
- **Styling**: Tailwind CSS
- **JavaScript**: esbuild bundler
- **Email**: Swoosh mailer
- **HTTP Client**: Req
- **JSON**: Jason

## Development Tools
- **Live Reload**: Phoenix Live Reload
- **Testing**: ExUnit with Floki for HTML parsing
- **Monitoring**: Phoenix LiveDashboard, Telemetry
- **Code Formatting**: Built-in Elixir formatter with Phoenix/Ecto imports

## Common Commands

### Setup & Development
```bash
# Initial setup (install deps, setup DB, build assets)
mix setup

# Start development server
mix phx.server

# Start with interactive shell
iex -S mix phx.server
```

### Database Operations
```bash
# Create and migrate database
mix ecto.setup

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Create migration
mix ecto.gen.migration migration_name

# Run migrations
mix ecto.migrate
```

### Asset Management
```bash
# Setup assets (install Tailwind/esbuild if missing)
mix assets.setup

# Build assets for development
mix assets.build

# Build and minify assets for production
mix assets.deploy
```

### Testing
```bash
# Run tests (creates test DB if needed)
mix test

# Run tests with coverage
mix test --cover
```

### Code Quality
```bash
# Format code
mix format

# Check formatting
mix format --check-formatted
```