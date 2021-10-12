defmodule Ms2ex.Packets.ServerEnter do
  import Ms2ex.Packets.PacketWriter

  def bytes(character, account_wallet, character_wallet) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_long(character.id)
    |> put_short(character.channel_id)
    |> put_long(character.exp)
    |> put_long(character.rest_exp)
    |> put_long(character_wallet.mesos)
    |> put_long(account_wallet.merets)
    |> put_long()
    |> put_long(account_wallet.game_merets)
    |> put_long(account_wallet.event_merets)
    |> put_long()
    |> put_long(character_wallet.valor_tokens)
    |> put_long(character_wallet.trevas)
    |> put_long(character_wallet.rues)
    |> put_long(character_wallet.havi_fruits)
    |> put_long()
    |> put_long()
    |> put_long()
    |> put_long()
    |> put_long(account_wallet.meso_tokens)
    |> put_ustring(character.profile_url)
    |> put_byte()
    |> put_byte()
    |> put_short(length(character.discovered_maps))
    |> put_maps(character.discovered_maps)
    |> put_short(length(character.taxis))
    |> put_maps(character.taxis)
    |> put_long()
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
    |> put_ustring("")
  end

  defp put_maps(packet, []), do: packet

  defp put_maps(packet, [field_id | maps]) do
    packet
    |> put_int(field_id)
    |> put_maps(maps)
  end
end
