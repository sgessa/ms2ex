alias Ms2ex.{Characters, Color, Equips, Inventory, Inventory, ItemColor, Metadata, SkinColor, Users}
alias Inventory, as: Items
alias Items.Item

{:ok, account} =
  Users.create(%{
    username: "steve",
    password: "123"
  })

skin_color = SkinColor.build(Color.build(-82, -65, -22, -1), Color.build(-82, -65, -22, -1))

ears = %Item{item_id: 10500001} |> Metadata.Items.load()

hair_color = ItemColor.build(Color.build(47, 47, -86, -1), Color.build(-37, -123, 76, -1), Color.build(19, 19, 96, -1), 0)

hair =
  %Item{
    item_id: 10_200_001,
    color: hair_color,
    data: %Item.Hair{back_length: 1_065_353_216, front_length: 1_065_353_216}
  } |> Metadata.Items.load()

face_color = ItemColor.build(Color.build(41, 36, -75, -1), Color.build(-29, -29, -9, -1), Color.build(2, 7, 20, -1), 0)
face = %Item{item_id: 10_300_014, color: face_color} |> Metadata.Items.load()

face_decor = %Item{item_id: 10_400_002, data: String.duplicate(<<0>>, 16)} |> Metadata.Items.load()

top_color = ItemColor.build(Color.build(41, 36, -75, -1), Color.build(-29, -29, -9, -1), Color.build(2, 7, 20, -1), 0)
top = %Item{item_id: 11_400_631, color: top_color} |> Metadata.Items.load()

bottom_color = ItemColor.build(Color.build(0, 0, 0, -1), Color.build(0, 0, 0, -1), Color.build(0, 0, 0, -1), 0)
bottom = %Item{item_id: 11_500_538, color: bottom_color} |> Metadata.Items.load()

shoes_color = ItemColor.build(Color.build(51, 59, 63, -1), Color.build(27, 32, 35, -1), Color.build(15, 18, 20, -1), 0)
shoes = %Item{item_id: 11_700_709, color: shoes_color} |> Metadata.Items.load()

staff = %Item{item_id: 15260305} |> Metadata.Items.load()

{:ok, char} =
  Characters.create(account, %{
    name: "steve1337",
    level: 70,
    map_id: 2_000_023,
    job: :wizard,
    skin_color: skin_color
  })

{:ok, {:create, item}} = Inventory.add_item(char, ears)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)

{:ok, {:create, item}} = Inventory.add_item(char, hair)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)

{:ok, {:create, item}} = Inventory.add_item(char, face)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)

{:ok, {:create, item}} = Inventory.add_item(char, face_decor)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)

{:ok, {:create, item}} = Inventory.add_item(char, top)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)

{:ok, {:create, item}} = Inventory.add_item(char, bottom)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)

{:ok, {:create, item}} = Inventory.add_item(char, shoes)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)

{:ok, {:create, item}} = Inventory.add_item(char, staff)
{:ok, _equip} = Equips.equip(item.metadata.slot, item)
