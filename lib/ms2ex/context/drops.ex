defmodule Ms2ex.Context.Drops do
  @moduledoc """
  Rolls items from the server drop tables (individual drop boxes and global
  drop boxes), shared by mob loot and item boxes.

  Individual boxes roll per character: groups gate on the character's
  level, items are gender-filtered for smart-gender groups, gated on map,
  and job-weighted when the group has a smart drop rate, before rolling
  the weighted drop count. Global boxes roll per level with map
  type/continent gates. A nil map id disables map gating entirely.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Storage.Tables.GlobalDropItemBox
  alias Ms2ex.Storage.Tables.IndividualDropItem

  @doc """
  Rolls an individual drop box for a character. Options:

    * `:index` - selects the item at this ordinal within the resolved
      group, skipping requirement filters (select boxes; requires `:group`)
    * `:group` - restricts the roll to a single drop group
  """
  @spec individual_items(integer(), Schema.Character.t(), integer() | map(), keyword()) :: [
          Schema.Item.t()
        ]
  def individual_items(box_id, %Schema.Character{} = character, map, opts \\ []) do
    groups = IndividualDropItem.get(box_id)
    map = normalize_map(map)

    case {Keyword.get(opts, :index, -1), Keyword.get(opts, :group, -1)} do
      {index, group} when index >= 0 and group > 0 ->
        case Map.get(groups, to_string(group)) do
          nil -> []
          entry -> roll_selected_group(entry, character, index)
        end

      _ ->
        groups
        |> Map.values()
        |> Enum.reject(&(&1.min_level > character.level))
        |> Enum.flat_map(&roll_individual_group(&1, character, map))
    end
  end

  @doc """
  Rolls a global drop box against the given level (the mob's level for mob
  loot, the character's level for boxes).
  """
  @spec global_items(integer(), integer(), integer() | map()) :: [Schema.Item.t()]
  def global_items(box_id, level, map) do
    %{groups: groups, items: items} = GlobalDropItemBox.get(box_id)
    map = normalize_map(map)

    Enum.flat_map(groups, fn group ->
      if group_eligible?(group, level, map) do
        roll_global_group(group, items, level, map)
      else
        []
      end
    end)
  end

  defp normalize_map(nil), do: %{id: nil, type: nil, continent: nil}

  defp normalize_map(map_id) when is_integer(map_id) do
    property = map_id |> Storage.Maps.get_meta() |> get_in([:property]) || %{}
    %{id: map_id, type: property[:type], continent: property[:continent]}
  end

  defp normalize_map(map), do: map

  defp group_eligible?(group, level, map) do
    group.min_level <= level &&
      (group.max_level == 0 || group.max_level >= level) &&
      map_condition_ok?(group.map_type_condition, map.type) &&
      map_condition_ok?(group.continent_condition, map.continent)
  end

  defp map_condition_ok?(condition, _map_value) when is_nil(condition), do: true

  defp map_condition_ok?(0, _map_value), do: true
  defp map_condition_ok?(condition, map_value), do: condition == map_value

  defp roll_global_group(group, items, level, map) do
    amount = Context.Utils.pick_weighted(group.drop_counts, :probability).amount

    if amount == 0 do
      []
    else
      group_items(items, group.group_id)
      |> eligible_global_items(level, map)
      |> roll_global_items(amount)
    end
  end

  defp eligible_global_items(items, level, map) do
    Enum.filter(items, fn item ->
      item.min_level <= level &&
        (item.max_level == 0 || item.max_level >= level) &&
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

  # select boxes: the picked ordinal is created without requirement filters
  defp roll_selected_group(group, character, index) do
    group.items
    |> gendered_entries(group, character)
    |> Enum.at(index)
    |> case do
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
  # min side); the roll always lands between min and the effective max
  defp roll_count(%{min: min, max: max}), do: Enum.random(min..max(max, min))

  defp roll_rarity([]), do: 1

  defp roll_rarity(rarities), do: Context.Utils.pick_weighted(rarities, :probability).grade
end
