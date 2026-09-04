defmodule Ms2ex.Context.Achievements do
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ecto.Query, only: [from: 2]

  def list(owner_id),
    do: Repo.all(from achievement in Schema.Achievement, where: achievement.owner_id == ^owner_id)

  def create(attrs) do
    %Schema.Achievement{}
    |> Schema.Achievement.changeset(attrs)
    |> Repo.insert()
  end

  def update(achievement, attrs) do
    achievement
    |> Schema.Achievement.changeset(attrs)
    |> Repo.update()
  end

  @save_fields [:current_grade, :reward_grade, :favorite, :counter, :grades]

  # Progress is applied in memory before it is flushed, so the in-memory row
  # already carries the new values; the flush must write them regardless of
  # the diff a plain cast would compute.
  def save(achievement) do
    achievement
    |> Schema.Achievement.changeset(%{})
    |> then(fn changeset ->
      Enum.reduce(@save_fields, changeset, fn field, changeset ->
        Ecto.Changeset.force_change(changeset, field, Map.get(achievement, field))
      end)
    end)
    |> Repo.update()
  end
end
