defmodule Ms2ex.Packets.ServerEnter do
  import Ms2ex.Packets.PacketWriter

  @unlocked_hidden_maps [52_000_065]
  @unlocked_maps [2_000_062]

  def bytes(channel_id, character, wallet) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_long(character.id)
    |> put_short(channel_id)
    |> put_long(character.exp)
    |> put_long(character.rest_exp)
    |> put_long(wallet.mesos)
    |> put_long(wallet.merets)
    |> put_long()
    |> put_long(wallet.game_merets)
    |> put_long(wallet.event_merets)
    |> put_long()
    |> put_long(wallet.valor_tokens)
    |> put_long(wallet.trevas)
    |> put_long(wallet.rues)
    |> put_long(wallet.havi_fruits)
    |> put_long()
    |> put_long()
    |> put_long()
    |> put_long()
    |> put_long(wallet.meso_tokens)
    |> put_ustring(character.profile_url)
    |> put_byte()
    |> put_byte()
    |> put_short(length(@unlocked_hidden_maps))
    |> put_maps(@unlocked_hidden_maps)
    |> put_short(length(@unlocked_maps))
    |> put_maps(@unlocked_maps)
    |> put_long()
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
  end

  defp put_maps(packet, []), do: packet

  defp put_maps(packet, [map_id | maps]) do
    packet
    |> put_int(map_id)
    |> put_maps(maps)
  end
end
