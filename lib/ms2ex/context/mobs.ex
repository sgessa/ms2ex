defmodule Ms2ex.Context.Mobs do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Storage.Tables.ExpTable

  @doc """
  Rolls the mob's death drops from its `drop_info` metadata.

  Bosses drop shared global loot (unlocked) plus per-dealer individual
  loot; regular mobs drop global and individual loot locked to the tagged
  player. Mobs without drop metadata drop nothing. When `map_id` is given,
  drop groups/items are gated on the map's type, continent and id.
  """
  def drop_rewards(mob, map_id \\ nil) do
    drop_info = get_in(mob.npc.metadata, [:drop_info])

    if drop_info, do: drop_rewards_for(mob, drop_info, map_conditions(map_id))
  end

  @doc """
  Rolls the mob's on-hit drops from its `drop_info` metadata. Global hit
  boxes drop unlocked loot; individual hit boxes are locked to the player
  who dealt the hit.
  """
  def drop_hit_rewards(mob, map_id \\ nil) do
    drop_info = get_in(mob.npc.metadata, [:drop_info])

    if drop_info do
      mob_level = get_in(mob.npc.metadata, [:basic, :level]) || 1
      map = map_conditions(map_id)

      drop_global_boxes(mob, drop_info[:global_hit_drop_box_ids] || [], mob_level, nil, map)

      if receiver = mob.last_attacker do
        drop_individual_boxes(mob, receiver, drop_info[:individual_hit_drop_box_ids] || [], map)
      end
    end
  end

  @doc """
  Rolls corpse loot from the mob's `dead_global_drop_box_ids` and locks it
  to the player who struck the body. Drops on every corpse strike.
  """
  def drop_corpse_rewards(mob, %Schema.Character{} = character, map_id \\ nil) do
    drop_info = get_in(mob.npc.metadata, [:drop_info])

    if drop_info do
      mob_level = get_in(mob.npc.metadata, [:basic, :level]) || 1
      map = map_conditions(map_id)

      (drop_info[:dead_global_drop_box_ids] || [])
      |> Enum.flat_map(&Context.Drops.global_items(&1, mob_level, map))
      |> Enum.each(&Context.Field.add_mob_drop(mob, &1, character))
    end
  end

  def reward_exp(mob) do
    player = mob.first_attacker || mob.last_attacker

    case exp_reward(mob) do
      :none -> :ok
      amount -> Managers.Character.cast(player, {:earn_exp, amount})
    end
  end

  # a fixed custom value; -1 means level-based, zero means no exp at all.
  # missing metadata falls back to the legacy flat reward
  defp exp_reward(mob) do
    level = get_in(mob.npc.metadata, [:basic, :level]) || 1

    case get_in(mob.npc.metadata, [:basic, :custom_exp]) do
      nil -> :none
      0 -> :none
      -1 -> ExpTable.mob_exp(level) || :none
      amount -> amount
    end
  end

  defp drop_rewards_for(mob, drop_info, map) do
    mob_level = get_in(mob.npc.metadata, [:basic, :level]) || 1

    if boss?(mob.npc.metadata) do
      drop_global_boxes(mob, drop_info[:global_drop_box_ids] || [], mob_level, nil, map)
      drop_dealer_loot(mob, drop_info, map)
    else
      receiver = mob.first_attacker || mob.last_attacker

      if receiver do
        drop_global_boxes(mob, drop_info[:global_drop_box_ids] || [], mob_level, receiver, map)
        drop_individual_boxes(mob, receiver, drop_info[:individual_drop_box_ids] || [], map)
      end
    end
  end

  # a nil map id (e.g. tests) disables map gating entirely
  defp map_conditions(nil), do: %{id: nil, type: nil, continent: nil}

  defp map_conditions(map_id) do
    property = map_id |> Storage.Maps.get_meta() |> get_in([:property]) || %{}

    %{id: map_id, type: property[:type], continent: property[:continent]}
  end

  defp drop_dealer_loot(mob, drop_info, map) do
    mob.damage_dealers
    |> Map.values()
    |> Enum.each(fn character ->
      drop_individual_boxes(mob, character, drop_info[:individual_drop_box_ids] || [], map)
    end)
  end

  defp boss?(metadata) do
    get_in(metadata, [:basic, :friendly]) == 0 &&
      (get_in(metadata, [:basic, :class]) || 0) >= 3
  end

  defp drop_global_boxes(mob, box_ids, mob_level, receiver, map) do
    Enum.each(box_ids, fn box_id ->
      Context.Drops.global_items(box_id, mob_level, map)
      |> Enum.each(&Context.Field.add_mob_drop(mob, &1, receiver))
    end)
  end

  defp drop_individual_boxes(mob, %Schema.Character{} = character, box_ids, map) do
    Enum.each(box_ids, fn box_id ->
      Context.Drops.individual_items(box_id, character, map)
      |> Enum.each(&Context.Field.add_mob_drop(mob, &1, character))
    end)
  end
end
