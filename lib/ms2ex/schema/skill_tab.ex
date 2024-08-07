defmodule Ms2ex.Schema.SkillTab do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ms2ex.Schema

  schema "skill_tabs" do
    belongs_to :character, Schema.Character

    has_many :skills, Schema.Skill, on_replace: :delete

    field :name, :string
  end

  @doc false
  def changeset(skill_tab, attrs) do
    skill_tab
    |> cast(attrs, [:name])
    |> cast_assoc(:skills, with: &Schema.Skill.changeset/2)
    |> validate_required([:name])
  end

  @doc false
  def add(character, attrs) do
    %__MODULE__{}
    |> cast(attrs, [:id, :name])
    |> cast_assoc(:skills, with: &Schema.Skill.changeset/2)
    |> put_assoc(:character, character)
    |> validate_required([:name])
  end
end
