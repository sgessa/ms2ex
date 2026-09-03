defmodule Ms2ex.GameHandlers.PickupItem do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Packets.PacketReader

  def handle(packet, session) do
    {object_id, _packet} = get_int(packet)

    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    # a full inventory leaves the drop on the field; the field manager
    # removes it only when the pickup succeeded
    Context.Field.pickup_item(character, object_id)
  end
end
