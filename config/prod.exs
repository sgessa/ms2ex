import Config

config :ms2ex, Ms2exWeb.Endpoint,
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info

config :ms2ex, Ms2ex,
  skip_packet_logs: [
    "CHARACTER_LIST",
    "EMOTION",
    "FIELD_ADD_USER",
    "KEY_TABLE",
    "PLAYER_STAT",
    "PROXY_GAME_OBJ",
    "SEND_LOG",
    "USER_CHAT",
    "USER_SYNC"
  ]
