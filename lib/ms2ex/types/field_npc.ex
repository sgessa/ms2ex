defmodule Ms2ex.Types.FieldNpc do
  alias Ms2ex.Navigation
  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord
  alias Ms2ex.Enums
  alias Ms2ex.Context

  @type t :: %__MODULE__{}

  defstruct [
    :object_id,
    :npc,
    :field,
    :map_id,
    :position,
    :rotation,
    :spawn_point_id,
    :type,
    :stats,
    :first_attacker,
    :last_attacker,
    :damage_dealers,
    :animation,
    # the model's resolved idle sequence: what a standing npc reports and
    # what scripted emotions revert to after playing
    :idle_sequence_id,
    # a scripted emotion in progress: %{revert_at, idle_sequence_id} —
    # one-shot emotions revert to the idle sequence once their playback
    # length elapses
    :emote,
    :patrol,
    # aggro state (mobs only): %Battle{} while engaged or returning, nil
    # when idle
    :battle,
    :next_target_scan_at,
    # where the mob actually appeared (post spawn scatter); the return-home
    # walk targets this
    :origin,
    dead?: false,
    corpse?: false,
    send_control?: true,
    # set when the mob healed (arrived home): the field broadcasts a health
    # stat update so clients drop the pre-heal HP
    stat_dirty?: false,
    seq_counter: 0,
    last_control_at: 0,
    velocity: {0, 0, 0}
  ]

  # must match @idle_control_ms in Managers.Field; staggering keeps npcs from
  # all becoming dirty on the same tick
  @idle_control_ms 30

  def new(attrs) do
    idle_sequence_id = idle_sequence_id(attrs.npc)

    attrs =
      attrs
      |> Map.put(:rotation, to_coord(attrs.rotation))
      |> Map.put(:type, get_type(attrs.npc))
      |> Map.put(:idle_sequence_id, idle_sequence_id)
      |> Map.put(:animation, idle_sequence_id)
      |> Map.put(:stats, build_stats(attrs.npc.metadata.stat.stats))
      |> Map.put_new(
        :last_control_at,
        Ms2ex.sync_ticks() + :rand.uniform(@idle_control_ms)
      )
      |> Map.put_new(:damage_dealers, %{})
      |> Map.put_new(:battle, nil)
      # deadlines must seed from the live tick base: a constant 0 sits in
      # the future forever against the raw BEAM monotonic base
      |> Map.put_new(:next_target_scan_at, Ms2ex.sync_ticks())
      |> randomize_pos()

    field_npc = struct(__MODULE__, attrs)
    %{field_npc | origin: attrs[:origin] || field_npc.position}
  end

  defp to_coord(%Coord{} = coord), do: coord
  defp to_coord(nil), do: struct(Coord, %{})
  defp to_coord(map), do: struct(Coord, map)

  def get_type(npc) do
    friendly = get_in(npc.metadata, [:basic, :friendly]) || 0

    if friendly > 0, do: :npc, else: :mob
  end

  # every control packet names the sequence the client must loop; a fresh
  # npc reports its model's idle sequence. Models with no rig report 0 —
  # the client then plays its own default idle. Sending a raw sentinel id
  # instead would make the client loop whatever animation happens to sit
  # at that index on rigs large enough to have one (story-npc rigs do),
  # which surfaces as wrong, slowed idle motion
  defp idle_sequence_id(npc) do
    model = get_in(npc.metadata, [:model, :name])
    Storage.Animations.sequence_id(model, "Idle_A") || 0
  end

  @spawn_distance 250

  # spawn scatter mirrors the spawn kinds: hostile population docs spread
  # mobs in a coarse box around the spawn point keeping its ground height;
  # an explicit spawn radius scatters a circle whose scattered spot snaps
  # to the walkable surface (falling back to the authored spawn when the
  # scattered spot has none); every other spawn stands verbatim at its
  # authored position
  defp randomize_pos(%{type: :mob} = attrs) do
    position = to_coord(attrs.position)

    case Map.get(attrs, :spawn_radius) do
      radius when is_number(radius) and radius > 0 ->
        scatter_circle(attrs, position, radius)

      nil ->
        min_x = position.x - @spawn_distance
        max_x = position.x + @spawn_distance
        min_y = position.y - @spawn_distance
        max_y = position.y + @spawn_distance

        x = Context.Utils.rand_float(min_x, max_x)
        y = Context.Utils.rand_float(min_y, max_y)

        Map.put(attrs, :position, %{position | x: x, y: y})

      _zero_radius ->
        Map.put(attrs, :position, position)
    end
  end

  defp randomize_pos(attrs) do
    position = to_coord(attrs.position)

    case Map.get(attrs, :spawn_radius) do
      radius when is_number(radius) and radius > 0 ->
        scatter_circle(attrs, position, radius)

      _ ->
        Map.put(attrs, :position, position)
    end
  end

  defp scatter_circle(attrs, position, radius) do
    angle = :rand.uniform() * 2 * :math.pi()
    distance = :rand.uniform() * radius

    scattered = %{
      position
      | x: position.x + :math.cos(angle) * distance,
        y: position.y + :math.sin(angle) * distance
    }

    Map.put(
      attrs,
      :position,
      Navigation.snap_to_floor(Map.get(attrs, :map_id), scattered) || position
    )
  end

  # a scripted emotion takes over the npc's animation: it plays at bare
  # 1.0x rate (the control packet rides a 100 rate while an emote is
  # active) and reverts to the model's idle sequence once its playback
  # length elapses
  def play_emote(%__MODULE__{} = npc, animation_id, ms, now) do
    idle_sequence_id = npc.idle_sequence_id || animation_id

    %{
      npc
      | animation: animation_id,
        emote: %{revert_at: now + ms, idle_sequence_id: idle_sequence_id},
        send_control?: true
    }
  end

  defp build_stats(stats) do
    Enums.BasicStatType.all()
    |> Enum.map(fn stat -> {stat, 0} end)
    |> Map.new()
    |> Map.merge(stats)
    |> Enum.map(fn {stat, value} ->
      {stat,
       %{
         total: value,
         base: value,
         current: value
       }}
    end)
    |> Map.new()
  end
end
