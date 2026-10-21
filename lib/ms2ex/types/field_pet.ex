defmodule Ms2ex.Types.FieldPet do
  @moduledoc """
  A summoned pet on the field: the field actor rendering a pet item.
  Wild pets (taming targets) carry a taming rank and no owner.
  """

  alias Ms2ex.Enums
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @type t :: %__MODULE__{}

  defstruct [
    :object_id,
    # the pet item row: the pet's identity (name, exp, level, rarity)
    :item,
    :npc,
    # the pet metadata document (Storage.Pets)
    :pet,
    :owner_character_id,
    :owner_object_id,
    :position,
    :rotation,
    :map_id,
    # the npc stat triple map the field packet serializes
    :stats,
    # badge pet-skin override, else the pet's npc id
    :skin_id,
    # wild pets roll 1..100 at spawn (green < 70, yellow < 95, red >= 95)
    taming_rank: 0,
    taming_points: 0,
    scale: 1.0,
    # npc-control bookkeeping: pets ride the same control keepalive as npcs
    # (the client spawns and animates the model from the control stream),
    # sharing the npc control plan's cadence and dirty-flag semantics
    animation: 0,
    velocity: {0, 0, 0},
    seq_counter: 0,
    last_control_at: 0,
    send_control?: false,
    dead?: false,
    # the follow battle map (Battle.follow): navmesh route, repath timer
    battle: nil,
    # near-owner idle state: stand/emote beats and roam legs
    # (mirrors the npc idle routine the pet's action metadata carries)
    idle: nil
  ]

  @spec new(keyword() | map()) :: t()
  def new(attrs) do
    %__MODULE__{} = field_pet = struct(__MODULE__, Map.new(attrs))

    %__MODULE__{
      field_pet
      | position: to_coord(field_pet.position),
        rotation: to_coord(field_pet.rotation),
        stats: build_stats(field_pet.npc.metadata.stat.stats),
        animation: idle_sequence_id(field_pet.npc)
    }
  end

  @doc "The pet's display name, falling back to empty until renamed."
  def name(%__MODULE__{item: item}) do
    Types.ItemPet.get(item).name
  end

  defp to_coord(%Types.Coord{} = coord), do: coord
  defp to_coord(map) when is_map(map), do: struct(Types.Coord, map)
  defp to_coord(nil), do: struct(Types.Coord, %{})

  # mirrors the npc stat triple map: every basic stat present as
  # [total, base, current] with the metadata's values
  defp build_stats(stats) do
    Enums.BasicStatType.all()
    |> Enum.map(fn stat -> {stat, 0} end)
    |> Map.new()
    |> Map.merge(stats)
    |> Enum.map(fn {stat, value} ->
      {stat, %{total: value, base: value, current: value}}
    end)
    |> Map.new()
  end

  defp idle_sequence_id(npc) do
    model = get_in(npc.metadata, [:model, :name])
    Storage.Animations.sequence_id(model, "Idle_A") || 0
  end
end
