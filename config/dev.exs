import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.
config :ms2ex, Ms2exWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Do not include metadata nor timestamps in development logs
config :logger, :console,
  format: "[$level] $message\n",
  truncate: :infinity

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :ms2ex, Ms2ex.Repo,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :ms2ex, Ms2ex,
  skip_packet_logs: [
    "ADD_PORTAL",
    "CHARACTER_LIST",
    "CONTROL_NPC",
    "EMOTE",
    "FIELD_ADD_NPC",
    "FIELD_ADD_USER",
    "INSIGNIA",
    "INVENTORY_ITEM",
    "KEY_TABLE",
    "PLAYER_STATS",
    "PROXY_GAME_OBJ",
    "RIDE_SYNC",
    "SEND_LOG",
    "STATS",
    "USER_BATTLE",
    "USER_CHAT",
    "USER_SYNC",
    "VIBRATE"
  ]
