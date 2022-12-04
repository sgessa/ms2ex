import Config

if config_env() == :prod do
  # Configure your database
  db_user = System.get_env("DB_USER") || raise "DB_USER env variable not configured!"
  db_pass = System.get_env("DB_PASS") || raise "DB_PASS env variable not configured!"
  db_name = System.get_env("DB_NAME") || raise "DB_NAME env variable not configured!"
  db_host = System.get_env("DB_HOST") || "localhost"

  config :ms2ex, Ms2ex.Repo,
    username: db_user,
    password: db_pass,
    database: db_name,
    hostname: db_host,
    pool_size: 10

  config :ms2ex, Ms2exWeb.Endpoint, server: true
end

server_address =
  System.get_env("SERVER_ADDRESS") || raise "SERVER_ADDRESS env variable not configured!"

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
