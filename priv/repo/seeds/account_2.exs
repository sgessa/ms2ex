alias Ms2ex.{Characters, Color, Equips, Hair, Inventory, Items, ItemColor, SkinColor, Accounts}

{:ok, account} =
  Accounts.create(%{
    username: "icra",
    password: "123"
  })

skin_color = SkinColor.build(Color.build(-82, -65, -22, -1), Color.build(-82, -65, -22, -1))

ears = Items.init(10500001)

hair_color = ItemColor.build(Color.build(47, 47, -86, -1), Color.build(-37, -123, 76, -1), Color.build(19, 19, 96, -1), 0)

hair =
  Items.init(10_200_001, %{
    color: hair_color,
    data: %Hair{back_length: 1_065_353_216, front_length: 1_065_353_216}
  })

face_color = ItemColor.build(Color.build(41, 36, -75, -1), Color.build(-29, -29, -9, -1), Color.build(2, 7, 20, -1), 0)
face = Items.init(10_300_014, %{color: face_color})

face_decor = Items.init(10_400_002, %{data: String.duplicate(<<0>>, 16)})

top_color = ItemColor.build(Color.build(41, 36, -75, -1), Color.build(-29, -29, -9, -1), Color.build(2, 7, 20, -1), 0)
top = Items.init(11_400_631, %{color: top_color})

bottom_color = ItemColor.build(Color.build(0, 0, 0, -1), Color.build(0, 0, 0, -1), Color.build(0, 0, 0, -1), 0)
bottom = Items.init(11_500_538, %{color: bottom_color})

shoes_color = ItemColor.build(Color.build(51, 59, 63, -1), Color.build(27, 32, 35, -1), Color.build(15, 18, 20, -1), 0)
shoes = Items.init(11_700_709, %{color: shoes_color})

dagger = Items.init(13_160_311, %{enchants: 12, rarity: 5})

{:ok, char} =
  Characters.create(account, %{
    name: "icra1337",
    level: 70,
    field_id: 2_000_023,
    job: :thief,
    skin_color: skin_color
  })

{:ok, {:create, item}} = Inventory.add_item(char, ears)
{:ok, _equip} = Equips.equip(item)

{:ok, {:create, item}} = Inventory.add_item(char, hair)
{:ok, _equip} = Equips.equip(item)

{:ok, {:create, item}} = Inventory.add_item(char, face)
{:ok, _equip} = Equips.equip(item)

{:ok, {:create, item}} = Inventory.add_item(char, face_decor)
{:ok, _equip} = Equips.equip(item)

{:ok, {:create, item}} = Inventory.add_item(char, top)
{:ok, _equip} = Equips.equip(item)

{:ok, {:create, item}} = Inventory.add_item(char, bottom)
{:ok, _equip} = Equips.equip(item)

{:ok, {:create, item}} = Inventory.add_item(char, shoes)
{:ok, _equip} = Equips.equip(item)

{:ok, {:create, item}} = Inventory.add_item(char, dagger)
{:ok, _equip} = Equips.equip(item, :LH)

{:ok, {:create, item}} = Inventory.add_item(char, dagger)
{:ok, _equip} = Equips.equip(item, :RH)
