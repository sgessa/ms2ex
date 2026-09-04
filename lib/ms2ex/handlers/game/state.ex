defmodule Ms2ex.GameHandlers.State do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  @jump 0x00

  def handle(packet, %{character_id: character_id}) do
    {command, _packet} = get_byte(packet)

    if command == @jump do
      Managers.Quest.update_conditions(character_id, :jump)
    end
  end
end
