import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand(".")

source!([
  Path.absname(".env", env_dir_prefix),
  System.get_env()
])

# Ecto query log level (warning by default; "false" disables repo logs)
config :ms2ex, Ms2ex.Repo,
  log: env!("ECTO_LOG_LEVEL", :existing_atom, false),
  username: env!("DB_USER"),
  password: env!("DB_PASS"),
  database: env!("DB_NAME"),
  hostname: env!("DB_HOST")

server_address = env!("SERVER_ADDRESS", :string)
web_port = env!("WEB_PORT", :integer, 4000)

config :ms2ex, Ms2ex,
  login: %{host: server_address, port: 8531},
  world: %{
    name: "Paperwood",
    login: %{host: server_address, port: 20101},
    channels: [
      %{host: server_address, port: 20102},
      %{host: server_address, port: 20103}
    ]
  },
  ugc: %{
    # the client resolves upload paths relative to this url, so it must keep a
    # trailing file segment for the /ugc prefix to survive
    endpoint: "http://#{server_address}:#{web_port}/ugc/ws.asmx?wsdl",
    resource: "http://#{server_address}:#{web_port}/ugc",
    locale: "na",
    data_dir: env!("UGC_DATA_DIR", :string, Path.expand("priv/ugc", env_dir_prefix))
  }

config :ms2ex, Ms2exWeb.Endpoint, http: [port: web_port]

config :ms2ex, Oban,
  repo: Ms2ex.Repo,
  plugins: [
    {Oban.Plugins.Cron, crontab: [{"0 0 * * *", Ms2ex.Workers.DailyReset}]}
  ],
  queues: [default: 10]

# Imports server constants
config :ms2ex, :constants,
  character_max_level: 99,
  expand_skill_tab_cost: -990,
  out_of_bounds_fall_distance: 0,
  stat_point_limits: %{
    strength: 100,
    dexterity: 100,
    intelligence: 100,
    luck: 100,
    health: 100,
    critical_rate: 100
  },
  revival_penalty_tick: 3_600_000,
  revival_penalty_min_level: 10,
  hit_per_dead_count: 5,
  max_dead_count: 3,
  revival_invincible_tick: 5_000

config :ms2ex, packet_log_file: System.get_env("PACKET_LOG_FILE")

if config_env() == :prod do
  config :ms2ex, Ms2ex.Repo, pool_size: 10
  config :ms2ex, Ms2exWeb.Endpoint, server: true
end
