defmodule Ms2ex.Types.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types.FieldNpc
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
    :next_proc_tick,
    stat_modifiers: %{},
    can_proc: false,
    proc_count: 0
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
    |> tick_state()
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

  defp tick_state(%__MODULE__{} = buff) do
    buff
    |> Map.put(:next_proc_tick, (buff.effect.property[:delay_tick] || 0) + interval_tick(buff))
    |> Map.put(:can_proc, ticks?(buff))
    |> Map.put(:proc_count, 0)
  end

  def interval_tick(%__MODULE__{} = buff) do
    case buff.effect[:property] do
      %{interval_tick: tick} when is_integer(tick) and tick > 0 -> tick
      %{duration_tick: duration} -> duration + 1000
      _ -> 1000
    end
  end

  def ticks?(%__MODULE__{} = buff) do
    not is_nil(buff.effect[:recovery]) or
      not is_nil(get_in(buff.effect, [:dot, :damage])) or
      not is_nil(get_in(buff.effect, [:dot, :buff])) or
      tick_skills(buff) != []
  end

  def skills(%__MODULE__{} = buff), do: Map.get(buff.effect, :skills, [])

  def tick_skills(%__MODULE__{} = buff), do: Map.get(buff.effect, :tick_skills, [])

  def dot_amounts(%__MODULE__{} = buff) do
    case get_in(buff.effect, [:dot, :damage]) do
      nil ->
        {0, 0, 0}

      dot ->
        max_hp = owner_max_hp(buff.owner)
        cur_hp = owner_cur_hp(buff.owner)

        hp =
          if dot.is_const_damage do
            dot.hp_value
          else
            rate_dmg =
              Context.Damage.calculate_rate(dot.rate, buff.caster, buff.owner, dot.type == 1).dmg

            rate_dmg + dot.hp_value
          end

        hp = hp + trunc(dot.damage_by_target_max_hp * max_hp)
        hp = if dot.not_kill, do: min(hp, cur_hp - 1), else: hp

        {max(hp, 0), max(dot.sp_value, 0), max(dot.ep_value, 0)}
    end
  end

  defp owner_max_hp(%FieldNpc{} = mob), do: mob.stats.health.total
  defp owner_max_hp(%Schema.Character{} = character), do: character.stats.health_max

  defp owner_cur_hp(%FieldNpc{} = mob), do: mob.stats.health.current
  defp owner_cur_hp(%Schema.Character{} = character), do: character.stats.health_cur

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
