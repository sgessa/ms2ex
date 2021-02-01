defmodule Ms2ex.Skill do
  use Ecto.Schema
  import Ecto.Changeset

  schema "skills" do
    belongs_to :skill_tab, Ms2ex.SkillTab

    field :learned, :boolean, default: false
    field :level, :integer, default: 0
    field :skill_id, :integer
  end

  @doc false
  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:skill_id, :learned, :level])
    |> validate_required([:skill_id, :learned, :level])
  end
end
