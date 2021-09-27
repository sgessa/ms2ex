defmodule Ms2ex.Items do
  alias Ms2ex.Metadata
  alias Ms2ex.Inventory.Item

  def init(id, attrs) do
    %Item{item_id: id}
    |> Map.merge(attrs)
    |> Metadata.Items.load()
  end

  def exp?(%Item{item_id: 90_000_08}), do: true
  def exp?(%Item{}), do: false

  def merets?(%Item{item_id: 90_000_020}), do: true
  def merets?(%Item{}), do: false

  def mesos?(%Item{item_id: id}) when id in 90_000_001..90_000_003 do
    true
  end

  def mesos?(%Item{}), do: false

  def sp?(%Item{item_id: 90_000_009}), do: true
  def sp?(%Item{}), do: false

  def stamina?(%Item{item_id: 90_000_010}), do: true
  def stamina?(%Item{}), do: false
end
