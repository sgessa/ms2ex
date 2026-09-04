# A bag of test items for every seeded character: mounts to ride, unequipped
# gear to try on, and consumables / misc stacks to use.

alias Ms2ex.{Context, Repo, Schema}

test_bag = [
  # mounts
  {:mount, 50_600_001},
  {:mount, 50_600_002},
  # gear
  # {:gear, 11_300_000},        # male base skin — not a real item, the client rejects it
  # {:gear, 11_600_034},        # skin gloves (lands in the outfit tab)
  {:gear, 11_800_001},
  {:gear, 12_000_001},
  # spare weapons (wizard staff / thief dagger)
  {:gear, 15_200_001},
  {:gear, 13_100_001},
  # consumables & misc
  {:consumable, 20_300_001, 99},
  {:consumable, 20_300_002, 5},
  {:misc, 59_200_001, 99}
]

# seeding persists straight to the database; bag slots fill in insertion
# order, tracked per tab across the bag
next_slot = fn slots, item ->
  tab = Ms2ex.Types.Item.inventory_tab(item.metadata)
  slot = Map.get(slots, tab, 0)
  {slot, Map.put(slots, tab, slot + 1)}
end

Schema.Character
|> Repo.all()
|> Enum.each(fn character ->
  Enum.reduce(test_bag, %{}, fn
    {_kind, item_id}, slots ->
      item = Context.Items.init(item_id, %{rarity: 4, amount: 1})
      {slot, slots} = next_slot.(slots, item)
      {:ok, _item} = Context.Inventory.insert_item(character.id, %{item | inventory_slot: slot})
      slots

    {_kind, item_id, amount}, slots ->
      item = Context.Items.init(item_id, %{rarity: 4, amount: amount})
      {slot, slots} = next_slot.(slots, item)
      {:ok, _item} = Context.Inventory.insert_item(character.id, %{item | inventory_slot: slot})
      slots
  end)
end)
