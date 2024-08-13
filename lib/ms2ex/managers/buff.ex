defmodule Ms2ex.Managers.Buff do
  alias Ms2ex.Managers
  alias Ms2ex.Types.Buff

  def get(buff_id) do
    buff =
      buff_id
      |> process_name()
      |> Agent.get(& &1)

    # Reload caster
    {:ok, skill_cast} = Managers.SkillCast.get(buff.skill_cast.id)
    {:ok, caster} = Managers.Character.lookup(buff.caster.id)

    buff
    |> Map.put(:caster, caster)
    |> Map.put(:skill_cast, skill_cast)
  end

  def start(%Buff{} = buff) do
    Agent.start_link(fn -> buff end, name: process_name(buff.object_id))
  end

  def update(%Buff{} = buff, attrs) do
    buff = Map.merge(buff, attrs)

    Agent.update(process_name(buff.object_id), fn _buff ->
      buff
    end)

    buff
  end

  defp process_name(buff_id), do: :"buff:#{buff_id}"
end
