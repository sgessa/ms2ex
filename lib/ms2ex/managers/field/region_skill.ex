defmodule Ms2ex.Managers.Field.RegionSkill do
  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Net.SenderSession
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @splash_radius 800
  @splash_targets 8

  @doc """
  Map-placed skill zones (boost lanes, zone hazards): perpetual client-side
  zones at a fixed position. Each zone gets a stable source id for the field
  session; entering players receive the zone add frame and the client runs
  the zone effect while they stand inside. Ids draw from the field's local
  counter so they never collide with entities.
  """
  def load_zones(map_id, counter) do
    zones =
      map_id
      |> Storage.Maps.get_region_skills()
      |> Enum.with_index()
      |> Enum.map(fn {doc, index} ->
        %{
          source_id: counter + index,
          skill_id: doc.skill_id,
          skill_level: doc.skill_level,
          interval: doc[:interval] || 0,
          position: doc.position
        }
      end)

    Logger.debug(
      "region zones: map #{map_id} counter #{inspect(counter)} loaded #{length(zones)}"
    )

    {counter + length(zones), zones}
  end

  @doc "Sends the field's map-placed skill zones to an entering player."
  def send_zones(character, zones) do
    next_tick = Ms2ex.sync_ticks()

    Enum.each(zones, fn zone ->
      SenderSession.push(
        character,
        Packets.RegionSkill.add_zone(
          zone.source_id,
          zone.skill_id,
          zone.skill_level,
          next_tick + zone.interval,
          [zone.position]
        )
      )
    end)
  end

  @doc """
  Map cubes carrying a skill zone (boost/slow lanes, hazard water). Cube
  zones are not announced to clients — the lane visuals are map decor —
  the field ticks them and applies the zone skill's effect to players
  standing inside.
  """
  def load_cube_zones(map_id, counter) do
    zones =
      map_id
      |> Storage.Maps.get_cube_skills()
      |> Enum.with_index()
      |> Enum.map(fn {doc, index} ->
        attack = first_attack(doc.skill_id, doc.skill_level)

        %{
          source_id: counter + index,
          skill_id: doc.skill_id,
          skill_level: doc.skill_level,
          position: doc.position,
          range: attack[:range] || %{},
          damage: attack[:damage] || %{}
        }
      end)

    Logger.debug("cube zones: map #{map_id} counter #{inspect(counter)} loaded #{length(zones)}")

    {counter + length(zones), zones}
  end

  # the zone's hit volume and damage come from the skill's first attack:
  # box ranges form a rectangle centered on the cell, cylinders a circle of
  # radius = distance
  defp first_attack(skill_id, skill_level) do
    skill = Storage.Skills.get_meta(skill_id)
    %{motions: [%{attacks: [attack | _]} | _]} = skill.levels[to_string(skill_level)]
    attack
  end

  @doc """
  Applies each cube-skill zone's attack to the players standing inside:
  the zone's damage rule, then its effect as a buff (e.g. the boost lanes'
  movement-speed bonus). Re-applying while inside refreshes the effect
  window; the short effect duration expires it shortly after stepping off.
  """
  def tick_cube_zones(state) do
    zones = Map.get(state, :cube_skill_zones, [])

    Enum.reduce(zones, state, &tick_zone/2)
  end

  defp tick_zone(zone, state) do
    {hits, state} =
      players_in_zone(state, zone)
      |> Enum.reduce({[], state}, fn character_id, acc ->
        apply_zone(zone, character_id, tracked_position(state, character_id), acc)
      end)

    broadcast_tile(zone, hits, state)
    state
  end

  # the field's tracked position is current (updated on every user move),
  # unlike the character manager's copy
  defp tracked_position(state, character_id) do
    state
    |> Map.get(:player_positions, %{})
    |> Map.get(character_id, %{})
    |> Access.get(:position)
  end

  defp apply_zone(zone, character_id, position, {hits, state}) do
    case Managers.Character.call(character_id, :lookup) do
      {:ok, character} ->
        {_buff, state} =
          Managers.Field.Buff.add_effect_buff_for(
            zone.skill_id,
            zone.skill_level,
            character,
            character,
            state
          )

        {zone_hit(zone, character, position, hits), state}

      _ ->
        {hits, state}
    end
  end

  # a hit reduces the target's health (the stats write handles death) and
  # joins the tile record broadcast once per zone per tick
  defp zone_hit(zone, character, position, hits) do
    dmg = zone_damage(zone, character)

    if dmg > 0 do
      Managers.Character.cast(character, {:consume_stat, :health, dmg})

      hit = %{
        object_id: character.object_id,
        position: zone.position,
        direction: push_direction(position, zone.position),
        # [{type, amount}] — type 0 is a normal hit
        damages: [{0, dmg}]
      }

      [hit | hits]
    else
      hits
    end
  end

  # the zone's damage rule mirrors the reference priority: a share of the
  # target's max health, then a constant value
  # TODO: rate-based zone damage needs a caster stat context the field
  # doesn't have
  defp zone_damage(zone, character) do
    damage = Map.get(zone, :damage, %{})
    max_hp = Map.get(character.stats, :health_max, 0)
    hp_share = damage[:damage_by_target_max_hp] || 0

    cond do
      hp_share > 0 -> trunc(max_hp * hp_share)
      damage[:is_const_damage] == true -> damage[:value] || 0
      true -> 0
    end
  end

  # pushed targets fly away from the source; direction is the normalized
  # offset, zero when the source sits on the target
  defp push_direction(position, zone_pos) do
    dx = position.x - zone_pos.x
    dy = position.y - zone_pos.y
    dz = position.z - zone_pos.z
    dist_sq = dx * dx + dy * dy + dz * dz

    if dist_sq > 0.001 do
      dist = :math.sqrt(dist_sq)
      %{x: dx / dist, y: dy / dist, z: dz / dist}
    else
      %{x: 0, y: 0, z: 0}
    end
  end

  defp broadcast_tile(_zone, [], _state), do: :ok

  defp broadcast_tile(zone, hits, state) do
    record = %{
      skill_id: zone.skill_id,
      skill_level: zone.skill_level,
      targets: Enum.reverse(hits)
    }

    Managers.Field.broadcast(state.topic, Packets.SkillDamage.tile(record))
  end

  defp players_in_zone(state, zone) do
    state
    |> Map.get(:player_positions, %{})
    |> Enum.filter(fn {_character_id, entry} ->
      position = entry[:position]
      is_map(position) and inside_zone?(position, zone)
    end)
    |> Enum.map(fn {character_id, _entry} -> character_id end)
  end

  # the zone's hit volume follows the attack prism for the skill's range:
  # box ranges form a rectangle centered on the cube cell (region-buff apply
  # target), cylinder ranges a circle of radius = distance; both are raised
  # one block so the base sits above the cell top and rise by the height
  defp inside_zone?(position, zone) do
    range = Map.get(zone, :range, %{})
    zone_pos = zone.position
    base_z = zone_pos.z + Context.MapBlock.block_size()
    top_z = base_z + (range[:height] || 0) + (range[:range_add_z] || 0)

    horizontal_hit? =
      case range[:type] do
        1 -> inside_box?(position, zone_pos, range)
        2 -> inside_cylinder?(position, zone_pos, range)
        _ -> false
      end

    horizontal_hit? and position.z >= base_z and position.z <= top_z
  end

  defp inside_box?(position, zone_pos, range) do
    half_width = ((range[:width] || 0) + (range[:range_add_x] || 0)) / 2
    half_length = ((range[:distance] || 0) + (range[:range_add_y] || 0)) / 2

    abs(position.x - zone_pos.x) <= half_width and
      abs(position.y - zone_pos.y) <= half_length
  end

  defp inside_cylinder?(position, zone_pos, range) do
    dx = position.x - zone_pos.x
    dy = position.y - zone_pos.y
    radius = range[:distance] || 0
    dx * dx + dy * dy <= radius * radius
  end

  def add(skill_cast, state) do
    source_id = Ms2ex.generate_int()
    points = Types.SkillCast.magic_path(skill_cast)

    case Types.SkillCast.splash_skill_cast(skill_cast) do
      {splash_cast, splash} ->
        reg_skill = Packets.RegionSkill.add(source_id, splash_cast, points)
        Managers.Field.broadcast(state.topic, reg_skill)

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
        Managers.Field.broadcast(state.topic, reg_skill)

        duration = Types.SkillCast.duration(skill_cast)
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
        # only hostile mobs take player splash damage — friendly npcs
        # (quest givers, story spawns, ambient townsfolk) are untouchable
        npc.type == :mob and not npc.dead? and in_splash_range?(npc, splash_cast)
      end)
      |> Enum.take(@splash_targets)

    hit_mobs(splash_cast, targets, state)
  end

  defp hit_mobs(splash_cast, targets, state) do
    {mobs, state} =
      Enum.reduce(targets, {[], state}, fn {object_id, mob}, {mobs, state} ->
        dmg = Context.Damage.calculate(splash_cast, mob, false)

        case Managers.Field.Npc.damage(state, splash_cast.caster, dmg.dmg, object_id) do
          {:ok, damaged_mob, state} ->
            state = Managers.Field.Npc.apply_skill_effects(state, splash_cast, object_id)
            {[{damaged_mob, dmg} | mobs], state}

          {:error, state} ->
            {mobs, state}
        end
      end)

    if mobs != [] do
      Managers.Field.broadcast(
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
