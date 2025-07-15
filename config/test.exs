import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :flixir, Flixir.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "flixir_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :flixir, FlixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "KSEP2WqB3WEi8pSW34tXc/jOVIAABXM4wpF2KuCxT+AIZAptD9zjophXKAheK1O9",
  server: false

# In test we don't send emails
config :flixir, Flixir.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# TMDB API configuration for testing
config :flixir, :tmdb,
  api_key: "test_api_key",
  base_url: "https://api.themoviedb.org/3",
  image_base_url: "https://image.tmdb.org/t/p/w500",
  timeout: 1_000,
  max_retries: 1

# Search cache configuration for testing (shorter TTL for faster tests)
config :flixir, :search_cache,
  ttl_seconds: 5,  # 5 seconds for testing
  max_entries: 100,
  cleanup_interval: 1_000  # 1 second
