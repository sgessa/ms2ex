defmodule Ms2ex.Packets.CharacterInfo do
  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketWriter

  @stat_total 3

  def not_found(character_id) do
    __MODULE__
    |> build()
    |> put_long(character_id)
    |> put_bool(false)
  end

  def load(%Schema.Character{} = character) do
    {character, equipment_stats} =
      character
      |> Context.Characters.load_equips()
      |> Context.CharacterStats.apply()

    __MODULE__
    |> build()
    |> put_long(character.id)
    |> put_bool(true)
    |> put_long()
    |> put_long(character.id)
    |> put_time(DateTime.utc_now())
    |> put_buffer(details(character, equipment_stats))
    |> put_buffer(equips(character))
    |> put_buffer(badges())
  end

  defp details(character, equipment_stats) do
    stats = character.stats
    skin_color = character.skin_color || Types.SkinColor.build({0, 0, 0, 0}, {0, 0, 0, 0})

    ""
    |> put_long(character.account_id)
    |> put_long(character.id)
    |> put_ustring(character.name)
    |> put_short(character.level)
    |> put_int(Enums.Job.get_value(character.job))
    |> put_int(Schema.Character.job_id(character))
    |> put_int(Enums.Gender.get_value(character.gender))
    |> put_int(character.prestige_level)
    |> put_byte()
    |> put_basic_stats(stats)
    |> put_basic_rates(equipment_stats)
    |> put_special_rates(equipment_stats)
    |> put_special_values(equipment_stats)
    |> put_ustring(Map.get(character, :profile_url, ""))
    |> put_ustring(character.motto)
    |> put_ustring(Map.get(character, :guild_name, ""))
    |> put_ustring()
    |> put_ustring(Map.get(character, :home_name, ""))
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int(character.title_id)
    |> put_int()
    |> put_int()
    |> put_int(character.gear_score)
    |> put_time(character.updated_at)
    |> put_int()
    |> put_int()
    |> Types.SkinColor.put_skin_color(skin_color)
    |> put_short()
    |> put_long()
    |> put_ustring()
    |> put_ustring()
  end

  defp put_basic_stats(packet, stats) do
    Enum.reduce(0..(@stat_total - 1), packet, fn index, packet ->
      Enum.reduce(Enums.BasicStatType.ordered_keys(), packet, fn stat, packet ->
        put_long(packet, Map.get(stats, :"#{stat}_#{stat_suffix(index)}", 0))
      end)
    end)
  end

  defp stat_suffix(0), do: :max
  defp stat_suffix(1), do: :min
  defp stat_suffix(2), do: :cur

  defp put_basic_rates(packet, equipment_stats) do
    put_rates(
      packet,
      Enums.BasicStatType.ordered_keys(),
      Map.get(equipment_stats, :basic_rates, %{})
    )
  end

  defp put_special_rates(packet, equipment_stats) do
    put_rates(
      packet,
      Enums.SpecialStatType.ordered_keys(),
      Map.get(equipment_stats, :special_rates, %{})
    )
  end

  defp put_rates(packet, attributes, rates) do
    Enum.reduce(attributes, packet, fn attribute, packet ->
      put_float(packet, Map.get(rates, attribute, 0.0))
    end)
  end

  defp put_special_values(packet, equipment_stats) do
    values = Map.get(equipment_stats, :special_values, %{})

    Enum.reduce(Enums.SpecialStatType.ordered_keys(), packet, fn attribute, packet ->
      put_float(packet, Map.get(values, attribute, 0.0))
    end)
  end

  defp put_buffer(packet, buffer), do: put_int(packet, byte_size(buffer)) <> buffer

  defp equips(character) do
    equips = Enum.filter(character.equips, &(&1.inventory_tab in [:gear, :outfit]))

    ""
    |> put_byte(length(equips))
    |> Packets.InventoryItem.put_equips(equips, character)
    |> put_bool(true)
    |> put_long()
    |> put_long()
    |> put_byte()
  end

  defp badges, do: put_byte("", 0)
end
