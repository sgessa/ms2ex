defmodule Ms2ex.Context.Mobs do
  alias Ms2ex.Context
  alias Ms2ex.Enums
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
      |> Enum.flat_map(&global_drop_items(&1, mob_level, map))
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
  # then items are gender-filtered for smart-gender groups, gated on map,
  # and job-weighted when the group has a smart drop rate, before rolling
  # the weighted drop count and creating every id in the picked entries.
  defp individual_drop_items(box_id, %Schema.Character{} = character, map) do
    box_id
    |> IndividualDropItem.get()
    |> Map.values()
    |> Enum.flat_map(fn group ->
      if group.min_level > character.level do
        []
      else
        roll_individual_group(group, character, map)
      end
    end)
  end

  defp roll_individual_group(group, character, map) do
    amount = Context.Utils.pick_weighted(group.drop_counts, :probability).count
    items = eligible_individual_items(group, character, map)

    cond do
      amount == 0 -> []
      smart_zero?(group, items) -> roll_smart_item(items, character)
      true -> items |> job_weighted(group, character) |> roll_individual_items(amount)
    end
  end

  defp eligible_individual_items(group, character, map) do
    group.items
    |> gendered_entries(group, character)
    |> Enum.reject(&(&1.quest_id > 0))
    |> Enum.filter(&map_ok?(&1.map_ids, map.id))
  end

  defp roll_smart_item(items, character) do
    case Enum.find(items, &job_recommended?(&1, job_code(character))) do
      nil -> []
      item -> roll_individual_items([item], 1)
    end
  end

  defp smart_zero?(%{smart_drop_rate: rate}, items) when rate > 0 do
    items != [] && Enum.all?(items, &(&1.weight == 0))
  end

  defp smart_zero?(_, _), do: false

  # smart-gender groups drop only items whose gender restriction matches
  defp gendered_entries(items, %{smart_gender: true}, character) do
    gender = Enums.Gender.get_value(character.gender)

    Enum.filter(items, fn item ->
      item_gender = item_gender(item)
      item_gender == 2 || item_gender == gender
    end)
  end

  defp gendered_entries(items, _group, _character), do: items

  defp item_gender(item) do
    case item.ids |> Enum.find(&(&1 != 0)) do
      nil -> 2
      id -> gender_or_all(item_limit_value(id, :gender))
    end
  end

  defp gender_or_all(nil), do: 2
  defp gender_or_all(gender), do: gender

  defp job_code(%Schema.Character{job: job}), do: Enums.Job.get_value(job) || 1

  # smart-drop-rate groups reweight items by the player's job
  defp job_weighted(items, %{smart_drop_rate: rate}, character) when rate > 0 do
    job = job_code(character)

    Enum.map(items, fn item ->
      %{item | weight: weight_by_job(item, job)}
    end)
  end

  defp job_weighted(items, _group, _character), do: items

  defp weight_by_job(item, job) do
    recommends = job_recommends(item)

    cond do
      recommends == [] -> item.weight
      job in recommends || 0 in recommends -> item.proper_job_weight
      true -> item.improper_job_weight
    end
  end

  defp job_recommended?(item, job) do
    recommends = job_recommends(item)
    recommends == [] || job in recommends || 0 in recommends
  end

  defp job_recommends(item) do
    case item.ids |> Enum.find(&(&1 != 0)) do
      nil -> []
      id -> item_limit_value(id, :job_recommends) || []
    end
  end

  defp item_limit_value(id, key) do
    get_in(Storage.get(:item, id), [:limit, key])
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
