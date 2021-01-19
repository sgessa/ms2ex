defmodule Ms2ex.Repo do
  use Ecto.Repo,
    otp_app: :ms2ex,
    adapter: Ecto.Adapters.Postgres
end
