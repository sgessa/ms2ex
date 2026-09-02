import Config

# DB connection settings come from config/runtime.exs (via .env); only the
# sandbox pool is test-specific
config :ms2ex, Ms2ex.Repo, pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ms2ex, Ms2exWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# the game/login TCP listeners never start under test
config :ms2ex, :start_game_servers, false

config :ms2ex, Oban, testing: :manual, plugins: false
