defmodule Ms2ex.GameHandlers.Insignia do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Packets

  import Packets.PacketReader

  def handle(packet, session) do
    {insignia_id, _packet} = get_short(packet)
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    # an id absent from the table is ignored; otherwise the insignia is
    # applied and the display flag broadcast
    case Storage.Tables.Insignias.get(insignia_id) do
      {:ok, metadata} ->
        remove_insignia_buff(character)
        display = can_equip_insignia?(character, metadata, insignia_id)

        {:ok, character} = Context.Characters.update(character, %{insignia_id: insignia_id})
        Managers.Character.call(character, {:update, character})

        if display, do: apply_insignia_buff(character, metadata)

        Context.Field.broadcast(
          character,
          Packets.Insignia.update(character, insignia_id, display)
        )

      :error ->
        :ok
    end
  end

  # the insignia the player is wearing keeps its buff until it is swapped out
  defp remove_insignia_buff(character) do
    with {:ok, %{buff_id: buff_id}} <- Storage.Tables.Insignias.get(character.insignia_id),
         true <- buff_id > 0 do
      Context.Field.remove_effect_buff(character, buff_id)
    else
      _ -> :ok
    end
  end

  defp apply_insignia_buff(character, %{buff_id: buff_id, buff_level: buff_level})
       when buff_id > 0 do
    Context.Field.call(character, {:add_effect_buff, buff_id, buff_level, character})
  end

  defp apply_insignia_buff(_character, _metadata), do: :ok

  defp can_equip_insignia?(character, %{type: :vip}, _insignia_id) do
    with %Schema.PremiumMembership{} = membership <-
           Context.PremiumMemberships.get(character.account_id),
         false <- Context.PremiumMemberships.expired?(membership) do
      true
    else
      _ -> false
    end
  end

  defp can_equip_insignia?(character, %{type: :level}, _insignia_id) do
    character.level >= 50
  end

  defp can_equip_insignia?(character, %{type: :enchant}, _insignia_id) do
    character
    |> Managers.Inventory.list_equips()
    |> Enum.any?(&(&1.inventory_tab == :gear and &1.enchant_level >= 12 and &1.rarity > 3))
  end

  defp can_equip_insignia?(character, %{type: :trophy_point}, _insignia_id) do
    Enum.sum(character.trophies) >= 1000
  end

  defp can_equip_insignia?(character, %{type: :title, title_id: title_id}, _insignia_id) do
    titles = Context.Characters.list_titles(character)
    Enum.member?(titles, title_id)
  end

  defp can_equip_insignia?(character, %{type: :adventure_level}, _insignia_id) do
    character.prestige_level >= 100
  end

  defp can_equip_insignia?(_character, _metadata, _insignia_id), do: false
end
