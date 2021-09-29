defmodule Ms2ex.Items do
  alias Ms2ex.Metadata
  alias Ms2ex.Item

  def init(id, attrs \\ %{}) do
    %Item{item_id: id}
    |> Map.merge(attrs)
    |> Metadata.Items.load()
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
  def rue(amount), do: init(@valor_token_id, amount)

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
end
