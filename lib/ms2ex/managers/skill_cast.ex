defmodule Ms2ex.Managers.SkillCast do
  alias Ms2ex.Managers
  alias Ms2ex.Types.SkillCast

  @spec get(integer()) :: {:ok, Ms2ex.Types.SkillCast.t()} | :error
  def get(skill_cast_id) do
    if pid = Process.whereis(process_name(skill_cast_id)) do
      skill_cast = Agent.get(pid, & &1)

      # Reload caster
      {:ok, caster} = Managers.Character.call(skill_cast.caster.id, :lookup)
      {:ok, Map.put(skill_cast, :caster, caster)}
    else
      :error
    end
  end

  # idempotent: a cast uid may legitimately arrive through more than one
  # channel (e.g. SkillUse and StateSkill), and the second registration must
  # not tear down the session
  def start_link(%SkillCast{} = skill_cast) do
    case Agent.start_link(fn -> skill_cast end, name: process_name(skill_cast.id)) do
      {:ok, _} = ok ->
        ok

      {:error, {:already_started, _pid}} ->
        {:ok, process_name(skill_cast.id)}
    end
  end

  def stop(skill_cast_id) do
    case Process.whereis(process_name(skill_cast_id)) do
      nil -> :ok
      pid -> Agent.stop(pid)
    end
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
