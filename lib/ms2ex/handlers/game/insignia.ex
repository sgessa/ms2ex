defmodule Ms2ex.GameHandlers.Insignia do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Packets.PacketReader

  def handle(packet, session) do
    {insignia_id, _packet} = get_short(packet)
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    # an id absent from the table is ignored; otherwise the insignia is
    # applied and the display flag broadcast
    case Context.Insignias.equip(character, insignia_id) do
      {:ok, character, display} ->
        Context.Field.broadcast(
          character,
          Packets.Insignia.update(character, insignia_id, display)
        )

      :error ->
        :ok
    end
  end
end
