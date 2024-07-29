defmodule Ms2ex.Items do
  alias Ms2ex.{Item, Items, Metadata}

  def init(id, attrs \\ %{}) do
    %Item{item_id: id}
    |> Map.merge(attrs)
    |> load_metadata()
    |> set_stats()
    |> set_level()
  end

  def set_level(%Item{metadata: metadata} = item) do
    Map.put(item, :level, metadata.limit.level)
  end

  def set_stats(%Item{} = item) do
    Map.put(item, :stats, Items.Stats.create(item))
  end

  def type(%Item{item_id: item_id}) do
    case trunc(item_id / 100_000) do
      112 -> :earring
      113 -> :hat
      114 -> :clothes
      115 -> :pants
      116 -> :gloves
      117 -> :shoes
      118 -> :cape
      119 -> :necklace
      120 -> :ring
      121 -> :belt
      122 -> :overall
      130 -> :bludgeon
      131 -> :dagger
      132 -> :longsword
      133 -> :scepter
      134 -> :throwing_star
      140 -> :spellbook
      141 -> :shield
      150 -> :greatsword
      151 -> :bow
      152 -> :staff
      153 -> :cannon
      154 -> :blade
      155 -> :knuckle
      156 -> :orb
      209 -> :medal
      id when id in [410, 420, 430] -> :lapenshard
      id when id in [501, 502, 503, 504, 505] -> :furnishing
      600 -> :pet
      900 -> :currency
      _ -> :none
    end
  end

  @meso_ids 90_000_001..90_000_003
  def mesos?(%Item{}), do: false
  def mesos?(%Item{item_id: id}) when id in @meso_ids, do: true
  def mesos(amount), do: init(List.first(@meso_ids), amount)

  @meret_ids [90_000_004, 90_000_011, 90_000_015, 90_000_016]
  def merets?(%Item{item_id: id}) when id in @meret_ids, do: true
  def merets?(%Item{}), do: false
  def merets(amount), do: init(List.first(@meret_ids), amount)

  @valor_token_id 90_000_006
  def valor_token?(%Item{item_id: @valor_token_id}), do: true
  def valor_token?(%Item{}), do: false
  def valor_token(amount), do: init(@valor_token_id, amount)

  @rue_id 90_000_013
  def rue?(%Item{item_id: @rue_id}), do: true
  def rue?(%Item{}), do: false
  def rue(amount), do: init(@rue_id, amount)

  @havi_fruit_id 90_000_014
  def havi_fruit?(%Item{item_id: @havi_fruit_id}), do: true
  def havi_fruit?(%Item{}), do: false
  def havi_fruit(amount), do: init(@havi_fruit_id, amount)

  @sp_id 90_000_009
  def sp?(%Item{item_id: @sp_id}), do: true
  def sp?(%Item{}), do: false
  def sp(amount), do: init(@sp_id, amount)

  @stamina_id 90_000_010
  def stamina?(%Item{item_id: @stamina_id}), do: true
  def stamina?(%Item{}), do: false
  def stamina(amount), do: init(@stamina_id, amount)

  @accessory_slots [:FH, :EA, :PD, :BE, :RI]
  def accessory?(%Item{} = item) do
    slots = Enum.map(@accessory_slots, &Ms2ex.Enum.EquipSlot.get_value(&1))
    !!Enum.find(item.metadata.slot_names, &(&1 in slots))
  end

  @armor_slots [:CP, :CL, :GL, :SH, :MT]
  def armor?(%Item{} = item) do
    slots = Enum.map(@armor_slots, &Ms2ex.Enum.EquipSlot.get_value(&1))
    !!Enum.find(item.metadata.slot_names, &(&1 in slots))
  end

  @weapon_slots [:LH, :RH, :OH]
  def weapon?(%Item{} = item) do
    slots = Enum.map(@weapon_slots, &Ms2ex.Enum.EquipSlot.get_value(&1))
    !!Enum.find(item.metadata.slot_names, &(&1 in slots))
  end

  def load_metadata(%Item{item_id: id} = item) do
    Map.put(item, :metadata, Metadata.get(Metadata.Item, id))
  end
end
