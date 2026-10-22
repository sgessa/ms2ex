defmodule Ms2ex.GameHandlers.RequestPetInventory do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  @command_add 0x0
  @command_remove 0x1
  @command_move 0x3
  @command_load 0x7

  @commands %{
    add: @command_add,
    remove: @command_remove,
    move: @command_move,
    load: @command_load
  }

  @specs %{
    @command_add => [item_uid: :long, slot: :short, amount: :int],
    @command_remove => [item_uid: :long, slot: :short, amount: :int],
    @command_move => [item_uid: :long, dst_slot: :short],
    @command_load => []
  }

  @impl true
  def commands, do: @commands

  @impl true
  def spec(command), do: Map.get(@specs, command, [])

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      handle_command(command, packet, character)
    end

    session
  end

  defp handle_command(command, packet, character)
       when command in [@command_add, @command_remove] do
    {item_uid, packet} = get_long(packet)
    {slot, packet} = get_short(packet)
    {amount, _packet} = get_int(packet)

    pet = Managers.Character.pet_summoned(character.id)

    if amount > 0 and pet do
      apply(command, character, pet, item_uid, slot, amount)
    end
  end

  defp handle_command(@command_move, packet, character) do
    {item_uid, packet} = get_long(packet)
    {dst_slot, _packet} = get_short(packet)

    pet = Managers.Character.pet_summoned(character.id)

    if pet do
      move_bag_stack(character, pet, item_uid, dst_slot)
    end
  end

  defp handle_command(@command_load, _packet, character) do
    pet = Managers.Character.pet_summoned(character.id)

    if pet do
      bag = Managers.Inventory.pet_bag_items(character.id, pet.item.id)
      push(character, Packets.PetInventory.load(bag, character))
    end
  end

  defp handle_command(_command, _packet, _character), do: :ok

  defp move_bag_stack(character, pet, item_uid, dst_slot) do
    case Managers.Inventory.pet_bag_move(character.id, pet.item.id, item_uid, dst_slot) do
      {:ok, %{src: src, src_slot: src_slot, dst: dst}} ->
        dst_uid = if dst, do: dst.id, else: 0
        push(character, Packets.PetInventory.move(dst_uid, src_slot, src.id, dst_slot))

      {:error, _reason} ->
        push(
          character,
          Packets.Notice.message_box(Enums.StringCode.get_value(:s_item_err_Invalid_slot))
        )
    end
  end

  # deposits `amount` of the inventory stack into the bag
  defp apply(@command_add, character, pet, item_uid, slot, amount) do
    case Managers.Inventory.pet_bag_add(
           character.id,
           pet.item.id,
           item_uid,
           slot,
           amount,
           pet.pet.item_slots
         ) do
      {:ok, %{source: source, bag: bag_row}} ->
        character
        |> then(&bag_packet(&1, bag_row, pet))
        |> Enum.each(&push(character, &1))

        character
        |> then(&inventory_packet(&1, source))
        |> Enum.each(&push(character, &1))

        sync_has_items(character)

      {:error, reason} ->
        push(
          character,
          Packets.Notice.message_box(Enums.StringCode.get_value(error_code(reason)))
        )
    end
  end

  # withdraws `amount` of the bag stack back into the inventory
  defp apply(@command_remove, character, pet, item_uid, slot, amount) do
    case Managers.Inventory.pet_bag_remove(
           character.id,
           pet.item.id,
           item_uid,
           slot,
           amount
         ) do
      {:ok, %{bag: bag_result, inventory: inv_result}} ->
        character
        |> then(&bag_packet(&1, bag_result, pet))
        |> Enum.each(&push(character, &1))

        character
        |> then(&inventory_packet(&1, inv_result))
        |> Enum.each(&push(character, &1))

        sync_has_items(character)

      {:error, reason} ->
        push(
          character,
          Packets.Notice.message_box(Enums.StringCode.get_value(error_code(reason)))
        )
    end
  end

  # the pet item's has-items flag follows the bag's emptiness; the updated
  # pet item re-serializes on the client from the pushed row
  # the pet item's has-items flag follows the bag's emptiness
  defp sync_has_items(character) do
    pet = Managers.Character.pet_summoned(character.id)

    if pet do
      bag_count =
        character.id
        |> Managers.Inventory.pet_bag_items(pet.item.id)
        |> length()

      Managers.Character.pet_set_has_items(character.id, bag_count > 0)
    end
  end

  defp error_code(:invalid_count), do: :s_item_err_invalid_count
  defp error_code(:pet_item), do: :s_pet_inventory_not_sendin_petitem
  defp error_code(:bag_full), do: :s_pet_inventory_not_sendin
  defp error_code(_other), do: :s_item_err_invalid_count

  # bag-side results: a new stack serializes fully, a merged stack only its
  # new amount, a consumed stack its removal
  defp bag_packet(character, {:create, row}, _pet),
    do: [Packets.PetInventory.add(row, character)]

  defp bag_packet(_character, {:update, row}, _pet),
    do: [Packets.PetInventory.update(row)]

  defp bag_packet(_character, {:delete, row}, _pet),
    do: [Packets.PetInventory.remove(row.id)]

  # player-side results mirror the inventory packet shapes
  defp inventory_packet(character, {:create, item}),
    do: [Packets.InventoryItem.add_item({:create, item}, character)]

  defp inventory_packet(_character, {:update, item}),
    do: [Packets.InventoryItem.update_item(item.id, item.amount)]

  defp inventory_packet(_character, {:delete, item}),
    do: [Packets.InventoryItem.remove_item(item.id)]

  defp inventory_packet(character, {:update_and_create, {updated, _amount}, created}),
    do: [
      Packets.InventoryItem.update_item(updated.id, updated.amount),
      Packets.InventoryItem.add_item({:create, created}, character)
    ]
end
