defmodule Ms2ex.Context.Mobs do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Storage.Tables.ExpTable
  alias Ms2ex.Storage.Tables.GlobalDropItemBox
  alias Ms2ex.Storage.Tables.IndividualDropItem

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
      global_drop_items(box_id, mob_level, map)
      |> Enum.each(&Context.Field.add_mob_drop(mob, &1, receiver))
    end)
  end

  defp drop_individual_boxes(mob, %Schema.Character{} = character, box_ids, map) do
    Enum.each(box_ids, fn box_id ->
      individual_drop_items(box_id, character, map)
      |> Enum.each(&Context.Field.add_mob_drop(mob, &1, character))
    end)
  end

  # Global box resolution: groups gate on mob level plus map type/continent,
  # roll a weighted drop count, then pick that many items from the group's
  # weighted entries.
  defp global_drop_items(box_id, mob_level, map) do
    %{groups: groups, items: items} = GlobalDropItemBox.get(box_id)

    Enum.flat_map(groups, fn group ->
      if group_eligible?(group, mob_level, map) do
        roll_global_group(group, items, mob_level, map)
      else
        []
      end
    end)
  end

  defp group_eligible?(group, mob_level, map) do
    group.min_level <= mob_level &&
      (group.max_level == 0 || group.max_level >= mob_level) &&
      map_condition_ok?(group.map_type_condition, map.type) &&
      map_condition_ok?(group.continent_condition, map.continent)
  end

  defp map_condition_ok?(condition, _map_value) when is_nil(condition), do: true

  defp map_condition_ok?(0, _map_value), do: true
  defp map_condition_ok?(condition, map_value), do: condition == map_value

  defp roll_global_group(group, items, mob_level, map) do
    amount = Context.Utils.pick_weighted(group.drop_counts, :probability).amount

    if amount == 0 do
      []
    else
      group_items(items, group.group_id)
      |> eligible_global_items(mob_level, map)
      |> roll_global_items(amount)
    end
  end

  defp eligible_global_items(items, mob_level, map) do
    Enum.filter(items, fn item ->
      item.min_level <= mob_level &&
        (item.max_level == 0 || item.max_level >= mob_level) &&
        !item.quest_constraint &&
        map_ok?(item.map_ids, map.id)
    end)
  end

  defp roll_global_items([], _amount), do: []

  defp roll_global_items(weighted, amount) do
    for _ <- 1..amount do
      item = Context.Utils.pick_weighted(weighted, :weight)
      Context.Items.drop_item(item.id, item.rarity, roll_count(item.drop_count))
    end
    |> Enum.reject(&is_nil/1)
  end

  defp group_items(items, group_id), do: Map.get(items, to_string(group_id), [])

  # item-level map gate: no restriction, or the drop map must be listed
  defp map_ok?(_map_ids, nil), do: true
  defp map_ok?([], _map_id), do: true
  defp map_ok?(map_ids, map_id), do: map_id in map_ids

  # Individual box resolution: per-player, groups gate on the player's level,
  # roll a weighted drop count, then pick that many items by weight, rolling
  # rarity for each and creating every id in the entry.
  defp individual_drop_items(box_id, %Schema.Character{level: level}, map) do
    box_id
    |> IndividualDropItem.get()
    |> Map.values()
    |> Enum.flat_map(fn group ->
      if group.min_level > level do
        []
      else
        roll_individual_group(group, map)
      end
    end)
  end

  defp roll_individual_group(group, map) do
    amount = Context.Utils.pick_weighted(group.drop_counts, :probability).count

    if amount == 0 do
      []
    else
      group.items
      |> Enum.reject(&(&1.quest_id > 0))
      |> Enum.filter(&map_ok?(&1.map_ids, map.id))
      |> roll_individual_items(amount)
    end
  end

  defp roll_individual_items([], _amount), do: []

  defp roll_individual_items(weighted, amount) do
    for _ <- 1..amount do
      item = Context.Utils.pick_weighted(weighted, :weight)
      rarity = roll_rarity(item.rarities)
      count = roll_count(item.drop_count)

      item.ids
      |> Enum.reject(&(&1 == 0))
      |> Enum.map(&Context.Items.drop_item(&1, rarity, count))
    end
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  # some entries carry max 0 with a positive min (the parser only clamps the
  # min side); roll at least the minimum like the reference's Next(min, max+1)
  defp roll_count(%{min: min, max: max}), do: Enum.random(min..max(max, min))

  defp roll_rarity([]), do: 1

  defp roll_rarity(rarities), do: Context.Utils.pick_weighted(rarities, :probability).grade
end
