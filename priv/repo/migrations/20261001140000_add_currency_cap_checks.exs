defmodule Ms2ex.Repo.Migrations.AddCurrencyCapChecks do
  use Ecto.Migration

  @moduledoc """
  Upper bounds for the capped token currencies, mirroring the caps the
  wallet context enforces from the client's server table (mesos and the
  meret family are unbounded).
  """

  def change do
    create(
      constraint(:wallets, :token_caps,
        check:
          "valor_tokens <= 5000 and trevas <= 75000 and rues <= 2000 and havi_fruits <= 35000"
      )
    )

    create(constraint(:account_wallets, :meso_token_cap, check: "meso_tokens <= 100000"))
  end
end
