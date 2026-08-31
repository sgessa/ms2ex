ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Ms2ex.Repo, :manual)

Mimic.copy(Ms2ex.Storage)
Mimic.copy(Ms2ex.Context.Characters)
Mimic.copy(Ms2ex.Context.Wallets)
