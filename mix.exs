defmodule Ms2ex.MixProject do
  use Mix.Project

  def project do
    [
      app: :ms2ex,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Ms2ex.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.9"},
      {:postgrex, "~> 0.16"},
      {:redix, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.7"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:protobuf, ">= 0.0.0"},
      {:google_protos, "~> 0.3.0"},
      {:varint, ">= 0.0.0"},
      {:libgraph, "~> 0.13"},
      {:ranch, "~> 2.0", override: true},
      {:luaport, "~> 1.6"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
