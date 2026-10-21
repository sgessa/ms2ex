defmodule Ms2ex.GameHandlers.RequestPetInventory do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  @command_add 0x0
  @command_remove 0x1
  @command_update 0x2
  @command_move 0x3
  @command_load 0x7
  @command_reset 0x6

  @commands %{
    add: @command_add,
    remove: @command_remove,
    update: @command_update,
    move: @command_move,
    load: @command_load,
    reset: @command_reset
  }

  @impl true
  def commands, do: @commands

  @impl true
  def spec(command) do
    case command do
      0x0 -> [_item_uid: :long, slot: :short, amount: :int]
      0x1 -> [_item_uid: :long, slot: :short, amount: :int]
      0x2 -> [_item_uid: :long, _amount: :int]
      0x3 -> [_item_uid: :long, dst_slot: :short]
      0x7 -> []
      _ -> []
    end
  end

  # TODO pet bag deposits/withdrawals/moves are unimplemented: the bag
  # contents and their persistence arrive with pet-bag support. The client
  # always asks for the bag contents on summon, so load answers with them
  def handle(packet, session) do
    {command, _packet} = get_byte(packet)

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    case command do
      @command_load ->
        push(session, Packets.PetInventory.load(pet_bag_items(character), character))

      _ ->
        :ok
    end

    session
  end

  # no pet carries items yet
  defp pet_bag_items(_character), do: []
end
