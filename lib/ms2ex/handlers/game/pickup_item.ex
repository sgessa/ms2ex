defmodule Ms2ex.GameHandlers.PickupItem do
  require Logger

  alias Ms2ex.{CharacterManager, Field, Packets}

  import Packets.PacketReader

  def handle(packet, session) do
    {object_id, _packet} = get_int(packet)

    {:ok, character} = CharacterManager.lookup(session.character_id)

    # TODO check that user inventory is not full
    Field.pickup_item(character, object_id)

    session
  end
end
