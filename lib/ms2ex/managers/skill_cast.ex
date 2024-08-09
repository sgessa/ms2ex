defmodule Ms2ex.Managers.SkillCast do
  alias Ms2ex.Managers
  alias Ms2ex.Types.SkillCast

  def get(skill_cast_id) do
    skill_cast =
      skill_cast_id
      |> process_name()
      |> Agent.get(& &1)

    # Reload caster
    {:ok, caster} = Managers.Character.lookup(skill_cast.caster.id)
    Map.put(skill_cast, :caster, caster)
  end

  def start(%SkillCast{} = skill_cast) do
    Agent.start_link(fn -> skill_cast end, name: process_name(skill_cast.id))
  end

  def update(%SkillCast{} = skill_cast, attrs) do
    skill_cast = Map.merge(skill_cast, attrs)

    Agent.update(process_name(skill_cast.id), fn _skill_cast ->
      skill_cast
    end)

    skill_cast
  end

  defp process_name(skill_cast_id), do: :"skill_cast:#{skill_cast_id}"
end
