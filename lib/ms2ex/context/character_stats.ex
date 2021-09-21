defmodule Ms2ex.Stats do
  alias Ms2ex.Character

  def consume_sp(%Character{} = character, amount) when amount <= 0, do: character

  def consume_sp(%Character{} = character, amount) do
    consume(character, :spirit, amount)
    # TODO maybe start SP regen
  end

  def consume_stamina(%Character{} = character, amount) when amount <= 0, do: character

  def consume_stamina(%Character{} = character, amount) do
    consume(character, :stamina, amount)
    # TODO maybe start STA regen
  end

  def consume(%Character{} = character, _stat, amount) when amount <= 0, do: character

  def consume(%Character{} = character, stat, amount) do
    cur = Map.get(character.stats, :"#{stat}_cur")
    amount = min(cur, amount)
    stats = Map.put(character.stats, :"#{stat}_cur", cur - amount)
    %{character | stats: stats}
  end
end
