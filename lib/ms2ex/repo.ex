defmodule Ms2ex.Repo do
  use Ecto.Repo,
    otp_app: :ms2ex,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query

  def first(q) do
    q |> limit(1) |> one()
  end

  def last(q) do
    sub = q |> select([q], max(q.id))
    q |> where([q], q.id in subquery(sub)) |> one()
  end

  def patch!(changeset, attrs) do
    changeset |> Ecto.Changeset.change(attrs) |> update!()
  end
end
