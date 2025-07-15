# Project Structure

## Root Level
- `mix.exs` - Project configuration and dependencies
- `mix.lock` - Dependency lock file
- `.formatter.exs` - Code formatting configuration
- `README.md` - Project documentation

## Core Application (`lib/`)
```
lib/
├── flixir/                    # Business logic layer
│   ├── application.ex         # OTP application entry point
│   ├── repo.ex               # Ecto repository
│   └── mailer.ex             # Email configuration
├── flixir_web/               # Web layer (Phoenix)
│   ├── components/           # Reusable UI components
│   ├── controllers/          # HTTP request handlers
│   ├── endpoint.ex           # Phoenix endpoint configuration
│   ├── router.ex             # URL routing
│   ├── gettext.ex            # Internationalization
│   └── telemetry.ex          # Metrics and monitoring
├── flixir.ex                 # Main application module
└── flixir_web.ex             # Web module definitions
```

## Configuration (`config/`)
- `config.exs` - Base configuration
- `dev.exs` - Development environment
- `prod.exs` - Production environment  
- `runtime.exs` - Runtime configuration
- `test.exs` - Test environment

## Database & Assets (`priv/`)
```
priv/
├── repo/
│   ├── migrations/           # Database schema changes
│   └── seeds.exs            # Database seed data
├── static/                  # Static web assets
└── gettext/                 # Translation files
```

## Frontend Assets (`assets/`)
```
assets/
├── css/
│   └── app.css              # Main stylesheet (Tailwind)
├── js/
│   └── app.js               # Main JavaScript entry
└── vendor/                  # Third-party assets
```

## Testing (`test/`)
```
test/
├── flixir_web/
│   └── controllers/         # Controller tests
├── support/
│   ├── conn_case.ex         # Test helpers for connections
│   └── data_case.ex         # Test helpers for data layer
└── test_helper.exs          # Test configuration
```

## Naming Conventions
- **Modules**: PascalCase (e.g., `FlixirWeb.PageController`)
- **Files**: snake_case matching module names
- **Functions**: snake_case
- **Variables**: snake_case
- **Atoms**: snake_case with colons (e.g., `:ok`, `:error`)

## Architecture Patterns
- **Context Pattern**: Business logic organized in contexts under `lib/flixir/`
- **Web Layer Separation**: All web-related code in `lib/flixir_web/`
- **Phoenix Conventions**: Controllers, views, templates follow Phoenix structure
- **Ecto Patterns**: Schemas, changesets, and queries follow Ecto conventions