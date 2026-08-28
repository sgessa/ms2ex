defmodule Ms2ex.Types.Buff do
  alias Ms2ex.Storage
  alias Ms2ex.Types.SkillCast

  defstruct [
    :object_id,
    :caster,
    :owner,
    :skill_cast,
    :skill,
    :start_tick,
    :end_tick,
    :stacks,
    :enabled,
    :effect,
    :shield_health,
    stat_modifiers: %{}
  ]

  def new(object_id, %SkillCast{} = skill_cast, skill, caster, owner) do
    effect =
      Storage.Skills.get_effect(skill[:id], skill[:level])

    attrs =
      Map.new()
      |> Map.put(:object_id, object_id)
      |> Map.put(:effect, effect)
      |> Map.put(:skill, skill)
      |> Map.put(:caster, caster)
      |> Map.put(:owner, owner)
      |> Map.put(:skill_cast, skill_cast)
      |> Map.put(:enabled, true)

    __MODULE__
    |> struct(attrs)
    |> stack()
    |> set_shield_health()
  end

  def stack(%__MODULE__{} = buff) do
    stacks = min(buff.stacks, buff.effect.property.max_count)
    start_tick = Ms2ex.sync_ticks()

    end_tick =
      if stacks == 1 or buff.effect.reset_condition != buff.effect.persist_end_tick,
        do: start_tick + buff.effect.property.duration_tick,
        else: buff.end_tick

    buff
    |> Map.put(:stacks, stacks)
    |> Map.put(:start_tick, start_tick)
    |> Map.put(:end_tick, end_tick)
  end

  def set_shield_health(%__MODULE__{} = buff) do
    shield = buff.effect[:shield]

    shield_health =
      cond do
        shield && shield[:hp_value] -> shield.hp_value
        shield -> buff.owner.stats.health_max * shield[:hp_by_target_max_hp]
        true -> 0
      end

    Map.put(buff, :shield_health, shield_health)
  end

  def recovery_amounts(%__MODULE__{} = buff, character, crit?) do
    case buff.effect[:recovery] do
      nil ->
        {0, 0, 0}

      recovery ->
        multiplier = if recovery[:disable_crit] or !crit?, do: 1.0, else: 1.5
        stats = character.stats

        {
          trunc(
            recovery[:hp_value] + recovery[:hp_rate] * stats.health_max +
              recovery[:recovery_rate] * stats.magical_atk_cur * multiplier
          ),
          trunc(recovery[:sp_value] + recovery[:sp_rate] * stats.spirit_max * multiplier),
          trunc(recovery[:ep_value] + recovery[:ep_rate] * stats.stamina_max * multiplier)
        }
    end
  end

  def stat_modifiers(%__MODULE__{} = buff, character) do
    status = buff.effect[:status] || %{}
    values = Map.get(status, :values, %{})
    rates = Map.get(status, :rates, %{})

    values
    |> Enum.reduce(%{}, fn {stat, value}, acc -> put_modifier(acc, character, stat, value) end)
    |> then(fn acc ->
      Enum.reduce(rates, acc, fn {stat, rate}, acc ->
        put_modifier(acc, character, stat, trunc(rate * stat_max(character, stat)))
      end)
    end)
  end

  defp put_modifier(acc, character, stat, amount) do
    if stat_max(character, stat) do
      Map.update(acc, stat, amount, &(&1 + amount))
    else
      acc
    end
  end

  defp stat_max(character, stat), do: Map.get(character.stats, :"#{stat}_max")
end
