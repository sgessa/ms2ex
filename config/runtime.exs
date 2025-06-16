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

server_address = env!("SERVER_ADDRESS", :string, "127.0.0.1")

config :ms2ex, Ms2ex,
  login: %{host: server_address, port: 8526},
  world: %{
    name: "Paperwood",
    login: %{host: server_address, port: 20001},
    channels: [
      %{host: server_address, port: 20002},
      %{host: server_address, port: 20003}
    ]
  },
  ugc: %{
    endpoint: "http://#{server_address}/ws.asmx?wsdl",
    resource: "http://#{server_address}",
    locale: "na"
  }

# Imports server constants
config :ms2ex, :constants,
  character_max_level: 70,
  expand_skill_tab_cost: -990

if config_env() == :prod do
  config :ms2ex, Ms2ex.Repo, pool_size: 10
  config :ms2ex, Ms2exWeb.Endpoint, server: true
end
