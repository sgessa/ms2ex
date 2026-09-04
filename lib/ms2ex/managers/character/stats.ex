defmodule Ms2ex.Managers.Character.Stats do
  alias Ms2ex.Context
  alias Ms2ex.Managers.Character
  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Storage.Tables

  @regen_stats %{health: :hp, spirit: :sp, stamina: :stamina}

  # server constants that suspend a stat's passive regen after consuming it;
  # the fallback matches the live constants table values
  @regen_wait_keys %{
    health: :recovery_hp_wait_tick,
    stamina: :recovery_ep_wait_tick
  }
  @default_regen_wait 1_000
  @min_regen_interval 100

  def decrease(character, stats, opts \\ []) do
    Enum.reduce(stats, character, fn {stat, amount}, character ->
      decrease(character, stat, amount, opts)
    end)
  end

  def decrease(character, stat_id, amount, opts) do
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    character = defer_regen(character, stat_id)
    set(character, stat_id, cur - amount, opts)
  end

  # every consumption pushes the stat's regen deadline back; regen resumes
  # the stat's Recovery*WaitTick after the last consumption
  defp defer_regen(character, stat_id) do
    if Map.has_key?(@regen_wait_keys, stat_id) do
      waits = Map.get(character, :regen_waits, %{})
      deadline = System.monotonic_time(:millisecond) + regen_wait(stat_id)
      Map.put(character, :regen_waits, Map.put(waits, stat_id, deadline))
    else
      character
    end
  end

  defp regen_wait(stat_id) do
    case Map.get(@regen_wait_keys, stat_id) do
      nil -> @default_regen_wait
      key -> Tables.Constants.get(key) || @default_regen_wait
    end
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

  def modify_max(character, stat_id, amount) do
    max = Map.get(character.stats, :"#{stat_id}_max", 0)
    cur = Map.get(character.stats, :"#{stat_id}_cur", 0)

    stats =
      character.stats
      |> Map.put(:"#{stat_id}_max", max(max + amount, 0))
      |> Map.put(:"#{stat_id}_cur", max(cur + amount, 0))

    character = %{character | stats: stats}

    broadcast_new_stats(character, stat_id)

    character
  end

  def set(character, stat_id, amount, opts \\ []) do
    total = Map.get(character.stats, :"#{stat_id}_max")
    amount = amount |> max(0) |> min(total)
    stats = Map.put(character.stats, :"#{stat_id}_cur", amount)
    regen_stat = Map.get(@regen_stats, stat_id)
    regen_key = :"regen_#{stat_id}?"

    character = %{character | stats: stats}

    character =
      if regen_stat && !Map.get(character, regen_key, false) && amount < total do
        intval = regen_interval(character.stats, regen_stat)
        Process.send_after(self(), {:regen, stat_id}, intval)
        Map.put(character, regen_key, true)
      else
        character
      end

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

  # the dead do not regenerate; the living regen one tick per scheduled
  # message until the stat is full or the actor dies
  def regen(%{dead?: true} = character, stat_id),
    do: Map.put(character, :"regen_#{stat_id}?", false)

  def regen(character, stat_id) do
    case regen_remaining_wait(character, stat_id) do
      rest when rest > 0 ->
        # consumption suspended this stat's regen; wake when the wait expires
        Process.send_after(self(), {:regen, stat_id}, rest)
        Map.put(character, :"regen_#{stat_id}?", true)

      _ ->
        regen_tick(character, stat_id)
    end
  end

  defp regen_remaining_wait(character, stat_id) do
    case Map.get(Map.get(character, :regen_waits, %{}), stat_id) do
      nil -> 0
      deadline -> deadline - System.monotonic_time(:millisecond)
    end
  end

  defp regen_tick(%{stats: stats} = character, stat_id) do
    regen_stat = @regen_stats[stat_id]
    intval = regen_interval(character.stats, regen_stat)
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    max = Map.get(character.stats, :"#{stat_id}_max")

    if cur < max do
      stat_cur = Map.get(stats, :"#{stat_id}_cur")
      stat_max = Map.get(stats, :"#{stat_id}_max")
      regen = Map.get(stats, :"#{regen_stat}_regen_cur")

      post_regen = stat_max |> min(stat_cur + regen) |> max(0)
      stats = Map.put(stats, :"#{stat_id}_cur", post_regen)
      character = %{character | stats: stats}

      send_new_stats(character, stat_id)
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

  defp regen_interval(stats, regen_stat) do
    stats
    |> Map.get(:"#{regen_stat}_regen_interval_cur")
    |> max(@min_regen_interval)
  end

  defp send_new_stats(character, stat_id) do
    Net.SenderSession.push(character, Packets.Stats.update_char_stats(character, [stat_id]))

    if stat_id == :health do
      PartyServer.broadcast(character.party_id, Packets.Party.update_hitpoints(character))
    end
  end
end
