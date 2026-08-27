defmodule Ms2ex.Context.Items do
  alias Ms2ex.Context
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @spec init(integer(), map()) :: Schema.Item.t()
  def init(id, attrs \\ %{}) do
    %Schema.Item{} = item = struct(Schema.Item, Map.merge(%{item_id: id}, attrs))

    item
    |> load_metadata()
    |> set_stats()
    |> set_level()
    |> Context.ItemTransfer.apply()
  end

  @doc """
  Builds a field-drop item from a drop table entry. Rolls rarity from the
  caller when present; a non-positive rarity falls back to the item's
  constant option, else rank 1. Returns `nil` when the item has no metadata.
  """
  @spec drop_item(integer(), integer(), integer()) :: Schema.Item.t() | nil
  def drop_item(item_id, rarity, amount) do
    case Storage.get(:item, item_id) do
      %{slot_names: _} = metadata ->
        init(item_id, %{rarity: resolve_rarity(rarity, metadata), amount: amount})

      _ ->
        nil
    end
  end

  defp resolve_rarity(rarity, _metadata) when rarity > 0, do: rarity

  defp resolve_rarity(_, %{option: %{constant_id: constant}}) when constant in 1..6,
    do: constant

  defp resolve_rarity(_, _), do: 1

  @spec set_level(Schema.Item.t()) :: Schema.Item.t()
  def set_level(%Schema.Item{metadata: metadata} = item) do
    %{item | level: metadata.limit.level}
  end

  @spec set_stats(Schema.Item.t()) :: Schema.Item.t()
  def set_stats(%Schema.Item{} = item) do
    %{item | stats: Types.ItemStats.create(item)}
  end

  @doc """
  Binds an item to a character when its transfer type requires it and the
  bind flag is set. Used before an INSERT (pickup), so the resulting struct
  carries the bind; the equip path merges the changeset form directly.
  """
  @spec bind_if_needed(Schema.Item.t(), :loot | :equip) :: Schema.Item.t()
  def bind_if_needed(%Schema.Item{} = item, on \\ :loot) do
    case Schema.Item.bind_if_needed(item, on) do
      %Ecto.Changeset{} = changeset -> Ecto.Changeset.apply_changes(changeset)
      item -> item
    end
  end

  @meso_ids [90_000_001, 90_000_002, 90_000_003]
  def mesos?(%Schema.Item{item_id: id}) when id in @meso_ids, do: true
  def mesos?(%Schema.Item{}), do: false
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

  @spec load_metadata(Schema.Item.t()) :: Schema.Item.t()
  def load_metadata(%Schema.Item{item_id: id} = item) do
    %{item | metadata: Storage.Items.get_meta(id)}
  end
end
