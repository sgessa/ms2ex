defmodule Ms2ex.Packets.DpsStat do
  import Ms2ex.Packets.PacketWriter

  def bytes(party) do
    __MODULE__
    |> build()
    |> put_int(Enum.count(party.members))
    |> reduce(party.members, fn member, packet ->
      packet
      |> put_long(member.id)
      |> put_long(Map.get(party.dps_damage, member.id, 0))
    end)
  end
end
