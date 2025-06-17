defmodule Ms2ex.Managers.Character.Stats do
  alias Ms2ex.PartyServer
  alias Ms2ex.Context
  alias Ms2ex.Packets

  @regen_stats %{health: :hp, spirit: :sp, stamina: :stamina}

  def decrease(character, stat_id, amount) do
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    set(character, stat_id, cur - amount)
  end

  def increase(character, stat_id, amount) do
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    max = Map.get(character.stats, :"#{stat_id}_max")

    amount = (cur + amount) |> max(0) |> min(max)
    stats = Map.put(character.stats, :"#{stat_id}_cur", amount)
    character = %{character | stats: stats}

    broadcast_new_stats(character, stat_id)

    character
  end

  def set(character, stat_id, amount) do
    total = Map.get(character.stats, :"#{stat_id}_max")
    amount = amount |> max(0) |> min(total)
    stats = Map.put(character.stats, :"#{stat_id}_cur", amount)
    regen_stat = Map.get(@regen_stats, stat_id)

    if regen_stat && !Map.get(character, :"regen_#{stat_id}?") && amount < total do
      intval = Map.get(character.stats, :"#{regen_stat}_regen_interval_cur")
      Process.send_after(self(), {:regen, stat_id}, intval)
    end

    character = %{character | stats: stats}
    broadcast_new_stats(character, stat_id)

    character
  end

  def regen(%{stats: stats} = character, stat_id) do
    intval = Map.get(character.stats, :"#{@regen_stats[stat_id]}_regen_interval_cur")
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    max = Map.get(character.stats, :"#{stat_id}_max")

    if cur < max do
      regen_stat = @regen_stats[stat_id]

      stat_cur = Map.get(stats, :"#{stat_id}_cur")
      stat_max = Map.get(stats, :"#{stat_id}_max")
      regen = Map.get(stats, :"#{regen_stat}_regen_cur")

      post_regen = stat_max |> min(stat_cur + regen) |> max(0)
      stats = Map.put(stats, :"#{stat_id}_cur", post_regen)
      character = %{character | stats: stats}

      broadcast_new_stats(character, stat_id)
      Process.send_after(self(), {:regen, stat_id}, intval)

      Map.put(character, :"regen_#{stat_id}?", true)
    else
      Map.put(character, :"regen_#{stat_id}?", false)
    end
  end

  def broadcast_new_stats(character, stat_id) do
    Context.Field.broadcast(character, Packets.Stats.update_char_stats(character, [stat_id]))
    PartyServer.broadcast(character.party_id, Packets.Party.update_hitpoints(character))
  end
end
