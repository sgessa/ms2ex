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

# tests never bind the game ports
server_ports =
  if config_env() == :test do
    %{login: 0, world: 0, channels: [0, 0]}
  else
    nil
  end

config :ms2ex, Ms2ex,
  login: %{host: server_address, port: (server_ports && server_ports.login) || 8526},
  world: %{
    name: "Paperwood",
    login: %{host: server_address, port: (server_ports && server_ports.world) || 20001},
    channels: [
      %{host: server_address, port: (server_ports && Enum.at(server_ports.channels, 0)) || 20002},
      %{host: server_address, port: (server_ports && Enum.at(server_ports.channels, 1)) || 20003}
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
  character_max_level: 70,
  expand_skill_tab_cost: -990

if config_env() == :prod do
  config :ms2ex, Ms2ex.Repo, pool_size: 10
  config :ms2ex, Ms2exWeb.Endpoint, server: true
end
