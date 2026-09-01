defmodule Ms2ex.GameHandlers.Tombstone do
  alias Ms2ex.Context
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  # a player hits a dead teammate's tombstone; enough hits revive the owner
  def handle(packet, session) do
    {object_id, packet} = get_int(packet)
    {hits, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      Context.Field.hit_tombstone(character, object_id, hits)
    end
  end
end
