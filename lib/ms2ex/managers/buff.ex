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

  def fetch(buff_id) do
    if pid = Process.whereis(process_name(buff_id)) do
      Agent.get(pid, & &1)
    end
  end

  def start(%Buff{} = buff) do
    Agent.start_link(fn -> buff end, name: process_name(buff.object_id))
  end

  def stop(buff_id) do
    if pid = Process.whereis(process_name(buff_id)) do
      Agent.stop(pid)
    end

    :ok
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
