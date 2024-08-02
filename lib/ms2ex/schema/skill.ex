defmodule Ms2ex.Schema.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  schema "skills" do
    belongs_to :skill_tab, Ms2ex.Schema.SkillTab

    field :level, :integer
    field :skill_id, :integer
  end

  @doc false
  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:skill_id, :level])
    |> validate_required([:skill_id, :level])
  end
end
