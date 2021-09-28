defmodule Ms2ex.Items do
  alias Ms2ex.Metadata
  alias Ms2ex.Item

  def init(id, attrs \\ %{}) do
    %Item{item_id: id}
    |> Map.merge(attrs)
    |> Metadata.Items.load()
  end

  def mesos?(%Item{}), do: false

  def mesos?(%Item{item_id: id}) when id in 90_000_001..90_000_003 do
    true
  end

  @meret_ids [90_000_004, 90_000_011, 90_000_015, 90_000_016]
  def merets?(%Item{item_id: id}) when id in @meret_ids, do: true
  def merets?(%Item{}), do: false

  def valor_token?(%Item{item_id: 90_000_006}), do: true
  def valor_token?(%Item{}), do: false

  def rue?(%Item{item_id: 90_000_013}), do: true
  def rue?(%Item{}), do: false

  def havi_fruit?(%Item{item_id: 90_000_014}), do: true
  def havi_fruit?(%Item{}), do: false

  def sp?(%Item{item_id: 90_000_009}), do: true
  def sp?(%Item{}), do: false

  def stamina?(%Item{item_id: 90_000_010}), do: true
  def stamina?(%Item{}), do: false
end
