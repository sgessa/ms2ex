defmodule Ms2ex.Managers.Field.RegionSkill do
  alias Ms2ex.Context
  alias Ms2ex.Managers.Field
  alias Ms2ex.Packets
  alias Ms2ex.Types.SkillCast

  @splash_radius 800
  @splash_targets 8

  def add(skill_cast, state) do
    source_id = Ms2ex.generate_int()
    points = SkillCast.magic_path(skill_cast)

    case SkillCast.splash_skill_cast(skill_cast) do
      {splash_cast, splash} ->
        reg_skill = Packets.RegionSkill.add(source_id, splash_cast, points)
        Context.Field.broadcast(state.topic, reg_skill)

        interval = Map.get(splash, :interval, 0) || 0
        fires = max(Map.get(splash, :fire_count, 0) || 0, 1)

        end_tick =
          Ms2ex.sync_ticks() + (Map.get(splash, :remove_delay, 0) || 0) + (fires - 1) * interval

        state =
          if interval > 0 and fires > 1 do
            state = apply_splash(splash_cast, state)

            region = %{
              splash_cast: splash_cast,
              interval: interval,
              fires_left: fires - 1,
              end_tick: end_tick
            }

            Process.send_after(self(), {:region_tick, source_id}, interval)
            put_in(state, [:regions, source_id], region)
          else
            apply_splash(splash_cast, state)
          end

        delay = max(end_tick - Ms2ex.sync_ticks(), 1)
        Process.send_after(self(), {:remove_region_skill, source_id}, delay)

        state

      nil ->
        reg_skill = Packets.RegionSkill.add(source_id, skill_cast, points)
        Context.Field.broadcast(state.topic, reg_skill)

        duration = SkillCast.duration(skill_cast)
        Process.send_after(self(), {:remove_region_skill, source_id}, duration + 5000)
        state
    end
  end

  def maybe_tick(source_id, state) do
    case Map.get(state.regions, source_id) do
      nil ->
        state

      region ->
        if region.fires_left <= 0 or Ms2ex.sync_ticks() >= region.end_tick do
          %{state | regions: Map.delete(state.regions, source_id)}
        else
          tick(region, source_id, state)
        end
    end
  end

  defp tick(region, source_id, state) do
    state = apply_splash(region.splash_cast, state)
    state = update_in(state, [:regions, source_id], &%{&1 | fires_left: &1.fires_left - 1})
    Process.send_after(self(), {:region_tick, source_id}, region.interval)
    state
  end

  def apply_splash(splash_cast, state) do
    targets =
      state.npcs
      |> Enum.filter(fn {_id, npc} ->
        not npc.dead? and in_splash_range?(npc, splash_cast)
      end)
      |> Enum.take(@splash_targets)

    hit_mobs(splash_cast, targets, state)
  end

  defp hit_mobs(splash_cast, targets, state) do
    {mobs, state} =
      Enum.reduce(targets, {[], state}, fn {object_id, mob}, {mobs, state} ->
        dmg = Context.Damage.calculate(splash_cast, mob, false)

        case Field.Npc.damage(state, splash_cast.caster, dmg.dmg, object_id) do
          {:ok, damaged_mob, state} ->
            state = Field.Npc.apply_skill_effects(state, splash_cast, object_id)
            {[{damaged_mob, dmg} | mobs], state}

          {:error, state} ->
            {mobs, state}
        end
      end)

    if mobs != [] do
      Context.Field.broadcast(
        state.topic,
        Packets.SkillDamage.damage(splash_cast, Enum.reverse(mobs))
      )
    end

    state
  end

  defp in_splash_range?(npc, splash_cast) do
    case {npc.position, splash_cast.position} do
      {%{x: x1, y: y1}, %{x: x2, y: y2}} ->
        (x1 - x2) ** 2 + (y1 - y2) ** 2 <= @splash_radius ** 2

      _ ->
        false
    end
  end
end
