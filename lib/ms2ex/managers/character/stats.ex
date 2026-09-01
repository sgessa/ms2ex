defmodule Ms2ex.Managers.Character.Stats do
  alias Ms2ex.PartyServer
  alias Ms2ex.Context
  alias Ms2ex.Managers.Character
  alias Ms2ex.Packets

  @regen_stats %{health: :hp, spirit: :sp, stamina: :stamina}

  def decrease(character, stats, opts \\ []) do
    Enum.reduce(stats, character, fn {stat, amount}, character ->
      decrease(character, stat, amount, opts)
    end)
  end

  def decrease(character, stat_id, amount, opts \\ []) do
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    set(character, stat_id, cur - amount, opts)
  end

  def increase(character, stats) do
    Enum.reduce(stats, character, fn {stat, amount}, character ->
      increase(character, stat, amount)
    end)
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

  def modify_max(character, modifiers, :increase) do
    Enum.reduce(modifiers, character, fn {stat, amount}, character ->
      modify_max(character, stat, amount)
    end)
  end

  def modify_max(character, modifiers, :reduce) do
    Enum.reduce(modifiers, character, fn {stat, amount}, character ->
      modify_max(character, stat, -amount)
    end)
  end

  def modify_max(character, stats, amount) when is_list(map) do
    Enum.reduce(modifiers, character, fn {stat, amount}, character ->
      modify_max(character, stat, amount)
    end)
  end

  def modify_max(character, stat_id, amount) do
    max = Map.get(character.stats, :"#{stat_id}_max", 0)
    cur = Map.get(character.stats, :"#{stat_id}_cur", 0)

    stats =
      character.stats
      |> Map.put(:"#{stat_id}_max", max + amount)
      |> Map.put(:"#{stat_id}_cur", min(cur, max + amount))

    character = %{character | stats: stats}

    broadcast_new_stats(character, stat_id)

    character
  end

  def set(character, stat_id, amount, opts \\ []) do
    total = Map.get(character.stats, :"#{stat_id}_max")
    amount = amount |> max(0) |> min(total)
    stats = Map.put(character.stats, :"#{stat_id}_cur", amount)
    regen_stat = Map.get(@regen_stats, stat_id)

    if regen_stat && !Map.get(character, :"regen_#{stat_id}?") && amount < total do
      intval = Map.get(character.stats, :"#{regen_stat}_regen_interval_cur")
      Process.send_after(self(), {:regen, stat_id}, intval)
    end

    character = %{character | stats: stats}

    if Keyword.get(opts, :broadcast, true) do
      broadcast_new_stats(character, stat_id)
    end

    # health reaching 0 kills the player; this is the single choke point all
    # health writes (decrease, set, damage) flow through
    if stat_id == :health do
      Character.check_death(character)
    else
      character
    end
  end

  def regen(%{dead?: false} = character, stat_id),
    do: Map.put(character, :"regen_#{stat_id}?", false)

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

    # the party HP packet must only be emitted when health itself changed;
    # spirit/stamina drains & regen fire constantly during combat
    if stat_id == :health do
      PartyServer.broadcast(character.party_id, Packets.Party.update_hitpoints(character))
    end
  end
end
