defmodule Ms2ex.Types.SkillCast do
  alias Ms2ex.Storage
  alias Ms2ex.Enums
  alias Ms2ex.Types.Coord

  @state_skill_drain_interval 1000

  @type t :: %__MODULE__{}
  defstruct [
    :client_tick,
    :server_tick,
    :next_tick,
    :id,
    :meta,
    :points,
    :skill_id,
    :skill_level,
    :position,
    :rotation,
    :direction,
    :rotate2z,
    :caster,
    :attack_counter,
    :item_uid,
    motion_point: 0,
    attack_point: 0
  ]

  def build(caster, attrs) do
    meta = Storage.Skills.get_meta(attrs[:skill_id])
    attrs = attrs |> Map.put(:meta, meta) |> Map.put(:caster, caster)

    struct(__MODULE__, attrs)
  end

  def skill_level(%__MODULE__{meta: meta, skill_level: level}) do
    meta.levels["#{level}"]
  end

  def use_item?(%__MODULE__{} = skill_cast) do
    level = skill_level(skill_cast)
    get_in(level, [:consume, :use_item]) || false
  end

  def cooldown(%__MODULE__{} = skill_cast, start_tick) do
    level = skill_level(skill_cast)
    state = Map.get(skill_cast.meta, :state, %{})

    cooldown_time = level[:cooldown_time] || 0
    recharge_max_count = Map.get(state, :recharge_max_count, 0)

    if cooldown_time > 0 or recharge_max_count > 0 do
      %{
        skill_id: skill_cast.skill_id,
        level: skill_cast.skill_level,
        start_tick: start_tick,
        end_tick: start_tick + trunc(cooldown_time * 1000),
        group_id: Map.get(state, :cooldown_group_id, 0),
        recharge_max_count: recharge_max_count,
        charges: 0
      }
    end
  end

  def duration(%__MODULE__{} = skill_cast) do
    case splash(skill_cast) do
      %{interval: interval} -> interval
      _ -> 0
    end
  end

  # cadence for a state skill's resource drain: the motion sequence speed in
  # milliseconds when projected, otherwise once per second. The fallback also
  # covers metadata ingested before motion_property was projected.
  def drain_interval(%__MODULE__{} = skill_cast) do
    case skill_level(skill_cast) do
      %{motions: [%{motion_property: %{sequence_speed: speed}} | _]}
      when is_number(speed) and speed > 0 ->
        trunc(speed * 1000)

      _ ->
        @state_skill_drain_interval
    end
  end

  def spirit_cost(%__MODULE__{} = skill_cast) do
    case skill_level(skill_cast) do
      %{consume: %{stat: %{spirit: sp}}} -> sp
      _ -> 0
    end
  end

  def stamina_cost(%__MODULE__{skill_level: lvl, meta: meta}) do
    case meta.levels["#{lvl}"] do
      %{consume: %{stat: %{stamina: stamina}}} -> stamina
      _ -> 0
    end
  end

  # the damage record of the relayed hit: the motion point the cast played and
  # the attack point that connected each pick their entry from the level doc
  # (a multi-attack skill — e.g. two projectiles — relays one hit per attack
  # point, each with its own rate/value). Client-sent indices never crash the
  # resolution: out-of-range points fall back to the motion's first attack
  defp damage_doc(%__MODULE__{} = skill_cast) do
    case resolved_attack(skill_cast) do
      nil -> %{}
      attack -> Map.get(attack, :damage) || %{}
    end
  end

  defp motion_point(%__MODULE__{motion_point: point}) when is_integer(point) and point >= 0,
    do: point

  defp motion_point(_), do: 0

  # 0xFF from the client marks "every attack at once"; there is no single
  # damage record for that, so the first attack stands in
  defp attack_point_index(%__MODULE__{attack_point: point})
       when is_integer(point) and point in 0..254, do: point

  defp attack_point_index(_), do: 0

  def damage_rate(%__MODULE__{} = skill_cast) do
    case damage_doc(skill_cast) do
      %{rate: rate} when is_number(rate) -> rate * 1.0
      _ -> 0.0
    end
  end

  def damage_value(%__MODULE__{} = skill_cast) do
    case damage_doc(skill_cast) do
      %{value: value} when is_number(value) -> value
      _ -> 0
    end
  end

  def physical?(%__MODULE__{meta: meta}) do
    meta.property.attack_type == Enums.AttackType.get_value(:physical)
  end

  def in_battle?(%__MODULE__{meta: meta}) do
    # defaults to true for skill metadata that predates the state projection
    Map.get(meta, :state, %{})[:in_battle] != false
  end

  def magic?(%__MODULE__{meta: meta}) do
    meta.property.attack_type == Enums.AttackType.get_value(:magic)
  end

  def condition_skills(%__MODULE__{skill_level: lvl, meta: meta}) do
    if skill_level = meta.levels["#{lvl}"] do
      skill_level.condition
    else
      []
    end
  end

  # on-hit effects applied to targets: the relayed attack's condition skills,
  # both the plain ones and the dependOnDamageCount ones (skills_on_damage)
  def attack_skills(%__MODULE__{} = skill_cast) do
    case resolved_attack(skill_cast) do
      nil ->
        []

      attack ->
        Map.get(attack, :skills, []) ++ Map.get(attack, :skills_on_damage, [])
    end
  end

  # the relayed hit's attack document: the motion point's attack at the
  # relayed attack point, falling back to the motion's first attack
  defp resolved_attack(%__MODULE__{} = skill_cast) do
    case damage_attacks(skill_cast) do
      [] ->
        nil

      attacks ->
        Enum.at(attacks, attack_point_index(skill_cast)) || Enum.at(attacks, 0)
    end
  end

  # the relayed motion's attack list (empty when the doc has none)
  defp damage_attacks(%__MODULE__{} = skill_cast) do
    with %{motions: motions} when is_list(motions) <- skill_level(skill_cast),
         motion when is_map(motion) <-
           Enum.at(motions, motion_point(skill_cast)) || Enum.at(motions, 0) do
      List.wrap(Map.get(motion, :attacks) || [])
    else
      _ -> []
    end
  end

  # the skill fired by a region/splash attack: returns the linked splash skill
  # id+level plus its splash timing so the region can be announced and ticked
  # with the correct metadata rather than a non-splash side effect listed first
  def splash_skill_cast(%__MODULE__{} = skill_cast) do
    case splash_effect(skill_cast) do
      %{id: id, level: level, splash: splash} when id > 0 ->
        cast = %__MODULE__{
          id: 0,
          skill_id: id,
          skill_level: level,
          caster: skill_cast.caster,
          meta: Storage.Skills.get_meta(id),
          position: skill_cast.position,
          rotation: skill_cast.rotation,
          attack_counter: skill_cast.attack_counter
        }

        {cast, splash}

      _ ->
        nil
    end
  end

  # the relayed hit's attack document, or nil when the cast carries no
  # attacks (buff casts)
  def attack_point(%__MODULE__{} = skill_cast) do
    resolved_attack(skill_cast)
  end

  def splash(%__MODULE__{} = skill_cast) do
    case splash_effect(skill_cast) do
      %{splash: splash} -> splash
      _ -> nil
    end
  end

  def splash_use_direction?(%__MODULE__{} = skill_cast) do
    case splash_effect(skill_cast) do
      %{splash: %{use_direction: false}} -> false
      _ -> true
    end
  end

  defp splash_effect(%__MODULE__{} = skill_cast) do
    skill_cast
    |> attack_skills()
    |> Enum.find(&(Map.get(&1, :has_splash, false) and is_map(Map.get(&1, :splash))))
  end

  def magic_path(%__MODULE__{} = skill_cast) do
    cube_magic_path_id = attack_point(skill_cast)[:cube_magic_path_id] || 0

    case Storage.Table.MagicPaths.get(cube_magic_path_id) do
      paths when is_list(paths) and paths != [] ->
        Enum.map(paths, fn path ->
          fire_offset = rotate_fire_offset(path, skill_cast.rotation)
          Coord.sum(skill_cast.position, fire_offset)

          # TODO align position unless path.ignoreAdjust
        end)

      _ ->
        [skill_cast.position]
    end
  end

  defp rotate_fire_offset(path, rotation) do
    fire_offset = struct(Coord, path[:fire_offset] || %{})

    if path[:rotate?] do
      Coord.rotate(fire_offset, rotation)
    else
      fire_offset
    end
  end
end
