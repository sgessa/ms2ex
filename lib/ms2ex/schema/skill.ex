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
  end
end
