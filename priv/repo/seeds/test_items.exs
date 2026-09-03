# A bag of test items for every seeded character: mounts to ride, unequipped
# gear to try on, and consumables / misc stacks to use.

alias Ms2ex.{Context, Repo, Schema}

test_bag = [
  # mounts
  {:mount, 50_600_001},
  {:mount, 50_600_002},
  # gear (no job limits, low level)
  {:gear, 11_300_000},
  {:gear, 11_600_034},
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

Repo.all(Schema.Character)
|> Enum.each(fn character ->
  Enum.each(test_bag, fn
    {_kind, item_id} ->
      item = Context.Items.init(item_id, %{rarity: 4, amount: 1})
      Context.Inventory.add_item(character, item)

    {_kind, item_id, amount} ->
      item = Context.Items.init(item_id, %{rarity: 4, amount: amount})
      Context.Inventory.add_item(character, item)
  end)
end)
