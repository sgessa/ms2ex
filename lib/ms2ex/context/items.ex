defmodule Ms2ex.Context.Items do
  alias Ms2ex.{Schema, Storage, Types}

  def init(id, attrs \\ %{}) do
    %Schema.Item{item_id: id}
    |> Map.merge(attrs)
    |> load_metadata()
    |> set_stats()
    |> set_level()
  end

  def set_level(%Schema.Item{metadata: metadata} = item) do
    Map.put(item, :level, metadata.limit.level)
  end

  def set_stats(%Schema.Item{} = item) do
    Map.put(item, :stats, Types.ItemStats.create(item))
  end

  @meso_ids [90_000_001, 90_000_002, 90_000_003]
  def mesos?(%Schema.Item{}), do: false
  def mesos?(%Schema.Item{item_id: id}) when id in @meso_ids, do: true
  def mesos(amount), do: init(List.first(@meso_ids), %{amount: amount})

  @meret_ids [90_000_004, 90_000_011, 90_000_015, 90_000_016]
  def merets?(%Schema.Item{item_id: id}) when id in @meret_ids, do: true
  def merets?(%Schema.Item{}), do: false
  def merets(amount), do: init(List.first(@meret_ids), %{amount: amount})

  @valor_token_id 90_000_006
  def valor_token?(%Schema.Item{item_id: @valor_token_id}), do: true
  def valor_token?(%Schema.Item{}), do: false
  def valor_token(amount), do: init(@valor_token_id, %{amount: amount})

  @rue_id 90_000_013
  def rue?(%Schema.Item{item_id: @rue_id}), do: true
  def rue?(%Schema.Item{}), do: false
  def rue(amount), do: init(@rue_id, %{amount: amount})

  @havi_fruit_id 90_000_014
  def havi_fruit?(%Schema.Item{item_id: @havi_fruit_id}), do: true
  def havi_fruit?(%Schema.Item{}), do: false
  def havi_fruit(amount), do: init(@havi_fruit_id, %{amount: amount})

  @sp_id 90_000_009
  def sp?(%Schema.Item{item_id: @sp_id}), do: true
  def sp?(%Schema.Item{}), do: false
  def sp(amount), do: init(@sp_id, %{amount: amount})

  @stamina_id 90_000_010
  def stamina?(%Schema.Item{item_id: @stamina_id}), do: true
  def stamina?(%Schema.Item{}), do: false
  def stamina(amount), do: init(@stamina_id, %{amount: amount})

  @accessory_slots [:FH, :EA, :PD, :BE, :RI]
  def accessory?(%Schema.Item{} = item) do
    Enum.any?(item.metadata.slots, &(&1 in @accessory_slots))
  end

  @armor_slots [:CP, :CL, :GL, :SH, :MT]
  def armor?(%Schema.Item{} = item) do
    Enum.any?(item.metadata.slots, &(&1 in @armor_slots))
  end

  @weapon_slots [:LH, :RH, :OH]
  def weapon?(%Schema.Item{} = item) do
    Enum.any?(item.metadata.slots, &(&1 in @weapon_slots))
  end

  def load_metadata(%Schema.Item{item_id: id} = item) do
    meta = Storage.Items.get_meta(id)
    Map.put(item, :metadata, meta)
  end
end
