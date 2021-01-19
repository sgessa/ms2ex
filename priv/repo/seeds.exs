alias Ms2ex.{Color, InventoryItems, ItemColor, SkinColor, Users}
alias InventoryItems.Item

{:ok, account} =
  Users.create(%{
    username: "steve",
    password: "123456"
  })

# ears = %Item{item_id: 10_500_001, slot_type: :ears}

hair_color =
  ItemColor.build(
    Color.build(47, 47, -86, -1),
    Color.build(-37, -123, 76, -1),
    Color.build(19, 19, 96, -1),
    0
  )

hair = %Item{
  item_id: 10_200_001,
  slot_type: :hair,
  color: hair_color,
  data: %Item.Hair{back_length: 1_065_353_216, front_length: 1_065_353_216}
}

face_color =
  ItemColor.build(
    Color.build(41, 36, -75, -1),
    Color.build(-29, -29, -9, -1),
    Color.build(2, 7, 20, -1),
    0
  )

face = %Item{item_id: 10_300_014, slot_type: :face, color: face_color}

face_decor = %Item{item_id: 10_400_002, data: String.duplicate(<<0>>, 16), slot_type: :face_decor}

top_color =
  ItemColor.build(
    Color.build(41, 36, -75, -1),
    Color.build(-29, -29, -9, -1),
    Color.build(2, 7, 20, -1),
    0
  )

top = %Item{item_id: 11_400_631, slot_type: :top, color: top_color}

bottom_color =
  ItemColor.build(
    Color.build(0, 0, 0, -1),
    Color.build(0, 0, 0, -1),
    Color.build(0, 0, 0, -1),
    0
  )

bottom = %Item{item_id: 11_500_538, slot_type: :bottom, color: bottom_color}

shoes_color =
  ItemColor.build(
    Color.build(51, 59, 63, -1),
    Color.build(27, 32, 35, -1),
    Color.build(15, 18, 20, -1),
    0
  )

shoes = %Item{item_id: 11_700_709, slot_type: :shoes, color: shoes_color}

{:ok, char} =
  Users.create_character(account, %{
    name: "steve1337",
    map_id: 2_000_023,
    position: {-39, -4347, 9001},
    job: :wizard,
    skin_color:
      SkinColor.build(
        Color.build(-82, -65, -22, -1),
        Color.build(-82, -65, -22, -1)
      )
  })

{:ok, {:create, _}} = InventoryItems.add_item(char, hair)
{:ok, {:create, _}} = InventoryItems.add_item(char, face)
{:ok, {:create, _}} = InventoryItems.add_item(char, face_decor)
{:ok, {:create, _}} = InventoryItems.add_item(char, top)
{:ok, {:create, _}} = InventoryItems.add_item(char, bottom)
{:ok, {:create, _}} = InventoryItems.add_item(char, shoes)

# {:ok, _} =
#   InventoryItems.add_item(char, %Item{
#     amount: 2,
#     item_id: 40_100_001,
#     max_slot: 5,
#     slot_type: :none,
#     tab_type: :catalyst
#   })
