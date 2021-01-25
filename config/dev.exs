use Mix.Config

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
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure your database
config :ms2ex, Ms2ex.Repo,
  username: "postgres",
  password: "postgres",
  database: "ms2ex_dev",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

server_host = System.get_env("SERVER_HOST") || "127.0.0.1"

config :ms2ex, Ms2ex,
  login: %{
    host: server_host,
    port: 20001
  },
  worlds: [
    %{
      name: "Paperwood",
      channels: [
        %{host: server_host, port: 20002},
        %{host: server_host, port: 20003}
      ]
    }
  ],
  ugc: %{
    endpoint: "http://#{server_host}/ws.asmx?wsdl",
    resource: "http://#{server_host}",
    locale: "na"
  },
  skip_packet_logs: ["CHARACTER_LIST", "FIELD_ADD_USER", "KEY_TABLE", "SEND_LOG", "USER_SYNC"]
