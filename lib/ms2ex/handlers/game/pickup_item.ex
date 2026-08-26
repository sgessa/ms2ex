defmodule Ms2ex.GameHandlers.PickupItem do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Packets.PacketReader

  def handle(packet, session) do
    {object_id, _packet} = get_int(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    # TODO check that user inventory is not full
    Context.Field.pickup_item(character, object_id)
  end
end
