# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ms2ex,
  ecto_repos: [Ms2ex.Repo]

# Configures the endpoint
config :ms2ex, Ms2exWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "RXZNWwLu0l2gpn74X+CcZka5hzXsVQ7sq0/sdjsiOGaH37IOK9Tvzjf4RI007BFH",
  render_errors: [view: Ms2exWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Ms2ex.PubSub,
  live_view: [signing_salt: "Z+IpM4Xe"]

# Configures Elixir's Logger
config :logger, :console,
  colors: [debug: :white, info: :green],
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

config :ms2ex, Ms2ex, version: 12, hash: "ce6ca622429e68b37650d519b326e293"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
