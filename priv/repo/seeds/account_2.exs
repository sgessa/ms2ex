alias Ms2ex.Context
alias Ms2ex.Types.{Color, Hair, ItemColor, SkinColor}

{:ok, account} =
  Context.Accounts.create(%{
    username: "icra",
    password: "123"
  })

skin_color = SkinColor.build(Color.build(-82, -65, -22, -1), Color.build(-82, -65, -22, -1))

ears = Context.Items.init(10500001)

hair_color = ItemColor.build(Color.build(47, 47, -86, -1), Color.build(-37, -123, 76, -1), Color.build(19, 19, 96, -1), 0)

hair =
  Context.Items.init(10_200_004, %{
    color: hair_color,
    data: %Hair{back_length: 0.20000000298023224, front_length: 1.0}
  })

face_color = ItemColor.build(Color.build(41, 36, -75, -1), Color.build(-29, -29, -9, -1), Color.build(2, 7, 20, -1), 0)
face = Context.Items.init(10_300_014, %{color: face_color})

face_decor = Context.Items.init(10_400_002, %{data: String.duplicate(<<0>>, 16)})

top_color = ItemColor.build(Color.build(41, 36, -75, -1), Color.build(-29, -29, -9, -1), Color.build(2, 7, 20, -1), 0)
top = Context.Items.init(11_400_631, %{color: top_color})

bottom_color = ItemColor.build(Color.build(0, 0, 0, -1), Color.build(0, 0, 0, -1), Color.build(0, 0, 0, -1), 0)
bottom = Context.Items.init(11_500_538, %{color: bottom_color})

shoes_color = ItemColor.build(Color.build(51, 59, 63, -1), Color.build(27, 32, 35, -1), Color.build(15, 18, 20, -1), 0)
shoes = Context.Items.init(11_700_709, %{color: shoes_color})

dagger = Context.Items.init(13_160_311, %{rarity: 5})

{:ok, char} =
  Context.Characters.create(account, %{
    name: "icra",
    level: 70,
    map_id: 2_000_023,
    job: :thief,
    skin_color: skin_color,
    guide_records: %{}
  })

# seeding persists straight to the database; no game session exists
outfit = [
  {ears, :ER},
  {hair, :HR},
  {face, :FA},
  {face_decor, :FD},
  {top, :CL},
  {bottom, :PA},
  {shoes, :SH},
  {dagger, :LH},
  {dagger, :RH}
]

Enum.each(outfit, fn {item, equip_slot} ->
  {:ok, _item} = Context.Inventory.insert_item(char.id, %{item | equip_slot: equip_slot, location: :equipment})
end)
