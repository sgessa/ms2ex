defmodule Ms2ex.Types.FieldSkill do
  alias Ms2ex.Types.Coord
  alias Ms2ex.Types.SkillCast
  alias Ms2ex.Storage

  defstruct [
    :caster,
    :interval,
    :fire_count,
    :use_direction,
    :end_tick,
    :next_tick,
    :position,
    :rotation,
    :skill_id,
    :skill_level,
    :field,
    active: true,
    points: []
  ]

  # Builds many Field Skills from Skill Cast Splash Effects

  def build(field, %SkillCast{} = skill_cast) do
    points = get_cube_points(skill_cast)

    skill_cast
    |> SkillCast.attack_point()
    |> Map.get(:skills)
    |> Enum.reject(&is_nil(&1[:splash]))
    |> Enum.flat_map(fn effect ->
      build(field, skill_cast, effect, points)
    end)
  end

  # Builds from generic attrs

  def build(field, attrs) do
    splash = attrs[:splash]
    use_direction = splash[:use_direction] || false
    interval = splash[:interval] || 0

    {next_tick, end_tick, active} = get_ticks(attrs)

    attrs =
      attrs
      |> Map.put(:use_direction, use_direction)
      |> Map.put(:interval, interval)
      |> Map.put(:next_tick, next_tick)
      |> Map.put(:end_tick, end_tick)
      |> Map.put(:active, active)
      |> Map.put(:field, field)

    [struct(__MODULE__, attrs)]
  end

  # Builds many Field Skills From Splash Effect Skills

  def build(field, skill_cast, %{splash: splash} = effect, points) do
    effect.skills
    |> Enum.map(&Storage.Skills.get_meta(&1.id)[:levels]["#{&1.level}"])
    |> Enum.reject(&is_nil(&1))
    |> Enum.flat_map(fn field_skill ->
      fire_count = if effect.fire_count > 0, do: effect.fire_count, else: -1

      build(field, %{
        caster: skill_cast.caster,
        meta: field_skill,
        fire_count: fire_count,
        splash: splash,
        points: points,
        position: hd(points),
        rotation: skill_cast.rotation,
        skill_id: skill_cast.skill_id,
        skill_level: skill_cast.skill_level
      })
    end)
  end

  # Utils

  defp get_cube_points(skill_cast) do
    cube_magic_path_id = SkillCast.attack_point(skill_cast)[:cube_magic_path_id] || 0

    case Storage.Table.MagicPaths.get(cube_magic_path_id) do
      paths when is_list(paths) and length(paths) > 0 ->
        Enum.map(paths, fn path ->
          # TODO fire_offset rotate if path.rotate?
          fire_offset = struct(Coord, path[:fire_offset] || %{})
          Coord.sum(skill_cast.position, fire_offset)

          # TODO align position unless path.ignoreAdjust
        end)

      _ ->
        [skill_cast.position]
    end
  end

  defp get_ticks(attrs) do
    splash = attrs[:splash]
    base_tick = Ms2ex.sync_ticks()

    interval = splash[:interval] || 0
    remove_delay = splash[:remove_delay] || 0
    fire_count = attrs[:fire_count] || 0
    delay = splash[:delay] || 0

    {next_tick, end_tick} =
      if splash[:immediate_active] do
        next_tick = base_tick
        end_tick = base_tick + remove_delay + (fire_count - 1) * interval
        {next_tick, end_tick}
      else
        next_tick = base_tick + delay + interval

        end_tick =
          base_tick + delay + remove_delay + fire_count * interval

        {next_tick, end_tick}
      end

    {end_tick, active} =
      if splash[:only_sensing_active] do
        end_tick = base_tick + delay + remove_delay
        {end_tick, false}
      else
        {end_tick, true}
      end

    {next_tick, end_tick, active}
  end
end
