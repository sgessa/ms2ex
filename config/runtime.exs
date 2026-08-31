import Config
import Dotenvy

env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand(".")

source!([
  Path.absname(".env", env_dir_prefix),
  System.get_env()
])

config :ms2ex, Ms2ex.Repo,
  username: env!("DB_USER"),
  password: env!("DB_PASS"),
  database: env!("DB_NAME"),
  hostname: env!("DB_HOST")

server_address = env!("SERVER_ADDRESS", :string)

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
    endpoint: "http://#{server_address}/ws.asmx?wsdl",
    resource: "http://#{server_address}",
    locale: "na"
  }

config :ms2ex, Ms2exWeb.Endpoint, http: [port: env!("WEB_PORT", :integer, 4000)]

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
}

config :ms2ex, packet_log_file: System.get_env("PACKET_LOG_FILE")

if config_env() == :prod do
  config :ms2ex, Ms2ex.Repo, pool_size: 10
  config :ms2ex, Ms2exWeb.Endpoint, server: true
end
