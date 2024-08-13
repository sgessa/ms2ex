defmodule Ms2ex.Schema.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ms2ex.EctoTypes
  alias Ms2ex.Enums

  schema "skills" do
    belongs_to :skill_tab, Ms2ex.Schema.SkillTab

    field :level, :integer
    field :max_level, :integer
    field :skill_id, :integer
    field :sub_skills, EctoTypes.Term
    field :rank, Enums.SkillRank
  end

  @doc false
  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:skill_id, :level, :rank, :max_level, :sub_skills])
    |> validate_required([:skill_id, :level, :rank, :max_level])
    |> maybe_update_subskills()
  end

  defp maybe_update_subskills(%{changes: %{level: level}} = cs) do
    sub_skills = cs |> get_field(:sub_skills) |> Enum.map(&Map.put(&1, :level, level))

    put_change(cs, :sub_skills, sub_skills)
  end

  defp maybe_update_subskills(cs), do: cs
end
