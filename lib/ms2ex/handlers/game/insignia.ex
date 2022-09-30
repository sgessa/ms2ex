defmodule Ms2ex.GameHandlers.Insignia do
  alias Ms2ex.{Characters, CharacterManager, Field, Inventory, Metadata, Packets}

  import Packets.PacketReader

  def handle(packet, session) do
    {insignia_id, _packet} = get_short(packet)
    {:ok, character} = CharacterManager.lookup(session.character_id)

    with {:ok, metadata} <- Metadata.Insignias.lookup(insignia_id),
         true <- can_equip_insignia?(character, metadata, insignia_id) do
      {:ok, character} = Characters.update(character, %{insignia_id: insignia_id})
      CharacterManager.update(character)
      Field.broadcast(character, Packets.Insignia.update(character, insignia_id, true))
    else
      _ ->
        Field.broadcast(character, Packets.Insignia.update(character, insignia_id, false))
    end
  end

  defp can_equip_insignia?(%{is_vip: is_vip}, %{type: "vip"}, _insignia_id), do: is_vip

  defp can_equip_insignia?(character, %{type: "level"}, _insignia_id) do
    character.level >= 50
  end

  defp can_equip_insignia?(character, %{type: "enchant"}, _insignia_id) do
    items = Inventory.all(character)
    if Enum.find(items, &(&1.enchant_level >= 12)), do: true, else: false
  end

  defp can_equip_insignia?(character, %{type: "trophy_point"}, _insignia_id) do
    Enum.sum(character.trophies) >= 1000
  end

  defp can_equip_insignia?(character, %{type: "title", title_id: title_id}, _insignia_id) do
    titles = Characters.list_titles(character)
    Enum.member?(titles, title_id)
  end

  defp can_equip_insignia?(character, %{type: "adventure_level"}, _insignia_id) do
    character.prestige_level >= 100
  end

  defp can_equip_insignia?(_character, _metadata, _insignia_id), do: false
end
