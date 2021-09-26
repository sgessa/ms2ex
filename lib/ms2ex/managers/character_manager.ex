defmodule Ms2ex.CharacterManager do
  use GenServer

  alias Ms2ex.{Character, Characters, Damage, Field, Packets, PartyServer, SkillCast, SkillStatus}

  import Ms2ex.GameHandlers.Helper.Session, only: [cleanup: 1]

  @regen_stats [:hp, :sp, :sta]

  def lookup(character_id), do: call(character_id, :lookup)

  # TODO avoid SQL
  def lookup_by_name(character_name) do
    case Characters.get_by(name: character_name) do
      nil -> :error
      %Character{id: char_id} -> lookup(char_id)
    end
  end

  def update(%Character{} = character), do: call(character, {:update, character})

  def monitor(%Character{} = character), do: call(character, :monitor)

  def cast_skill(%Character{} = character, %SkillCast{} = skill_cast) do
    call(character, {:cast_skill, skill_cast})
  end

  def receive_fall_dmg(%Character{} = character) do
    cast(character, :receive_fall_dmg)
  end

  def consume_stat(_character, _stat, amount) when amount <= 0, do: :error

  def consume_stat(%Character{} = character, stat, amount) do
    cast(character, {:consume_stat, stat, amount})
  end

  def increase_stat(_character, _stat, amount) when amount <= 0, do: :error

  def increase_stat(%Character{} = character, stat, amount) do
    cast(character, {:increase_stat, stat, amount})
  end

  def start(%Character{} = character) do
    GenServer.start(__MODULE__, character, name: process_name(character.id))
  end

  def init(character) do
    {:ok,
     character
     |> Map.put(:regen_hp?, false)
     |> Map.put(:regen_sp?, false)
     |> Map.put(:regen_sta?, false)}
  end

  def handle_call(:lookup, _from, character) do
    {:reply, {:ok, character}, character}
  end

  def handle_call({:update, character}, _from, _state) do
    {:reply, :ok, character}
  end

  def handle_call(:monitor, {pid, _}, character) do
    Process.monitor(pid)
    {:reply, :ok, character}
  end

  def handle_call({:cast_skill, skill_cast}, _from, %{stats: stats} = character) do
    sp_cost = SkillCast.sp_cost(skill_cast)
    stamina_cost = SkillCast.stamina_cost(skill_cast)

    if stats.sp_cur >= sp_cost and stats.sta_cur >= stamina_cost do
      character =
        character
        |> decrease_stat(:sp, sp_cost)
        |> decrease_stat(:sta, stamina_cost)

      if SkillCast.owner_buff?(skill_cast) or SkillCast.entity_buff?(skill_cast) or
           SkillCast.shield_buff?(skill_cast) or SkillCast.owner_debuff?(skill_cast) do
        status = SkillStatus.new(skill_cast, character.object_id, character.object_id, 1)
        Field.add_status(character, status)
      end

      Field.enter_battle_stance(character)

      character = %{character | skill_cast: skill_cast}
      {:reply, {:ok, character}, character}
    else
      {:reply, {:ok, character}, character}
    end
  end

  def handle_cast({:consume_stat, stat_id, amount}, character) do
    {:noreply, decrease_stat(character, stat_id, amount)}
  end

  def handle_cast({:increase_stat, stat_id, amount}, character) do
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    max = Map.get(character.stats, :"#{stat_id}_max")

    amount = (cur + amount) |> max(0) |> min(max)
    stats = Map.put(character.stats, :"#{stat_id}_cur", amount)
    character = %{character | stats: stats}

    broadcast_new_stats(character, stat_id)

    {:noreply, character}
  end

  def handle_cast(:receive_fall_dmg, character) do
    hp = Map.get(character.stats, :hp_cur)
    dmg = Damage.calculate_fall_dmg(character)
    character = set_stat(character, :hp, max(hp - dmg, 25))

    send(character.session_pid, {:push, Packets.FallDamage.bytes(character, 0)})

    {:noreply, character}
  end

  def handle_info({:regen, stat_id}, character) do
    intval = Map.get(character.stats, :"#{stat_id}_regen_time_cur")
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    max = Map.get(character.stats, :"#{stat_id}_max")

    if cur < max do
      # TODO check if regen enabled
      character = %{character | stats: regen(character.stats, stat_id)}
      broadcast_new_stats(character, stat_id)

      Process.send_after(self(), {:regen, stat_id}, intval)

      {:noreply, Map.put(character, :"regen_#{stat_id}?", true)}
    else
      {:noreply, Map.put(character, :"regen_#{stat_id}?", false)}
    end
  end

  def handle_info({:DOWN, _, _, _pid, _reason}, character) do
    cleanup(character)
    {:stop, :normal, character}
  end

  defp decrease_stat(character, stat_id, amount) do
    cur = Map.get(character.stats, :"#{stat_id}_cur")
    set_stat(character, stat_id, cur - amount)
  end

  defp set_stat(character, stat_id, amount) do
    total = Map.get(character.stats, :"#{stat_id}_max")
    amount = amount |> max(0) |> min(total)
    stats = Map.put(character.stats, :"#{stat_id}_cur", amount)

    if stat_id in @regen_stats && !Map.get(character, :"regen_#{stat_id}?") && amount < total do
      intval = Map.get(character.stats, :"#{stat_id}_regen_time_cur")
      Process.send_after(self(), {:regen, stat_id}, intval)
    end

    character = %{character | stats: stats}
    broadcast_new_stats(character, stat_id)

    character
  end

  defp regen(stats, stat_id) do
    stat_cur = Map.get(stats, :"#{stat_id}_cur")
    stat_max = Map.get(stats, :"#{stat_id}_max")
    regen = Map.get(stats, :"#{stat_id}_regen_cur")

    post_regen = stat_max |> min(stat_cur + regen) |> max(0)
    Map.put(stats, :"#{stat_id}_cur", post_regen)
  end

  defp broadcast_new_stats(character, stat_id) do
    Field.broadcast(character, Packets.Stats.update_char_stats(character, [stat_id]))
    PartyServer.broadcast(character.party_id, Packets.Party.update_hitpoints(character))
  end

  defp call(%Character{id: id}, msg), do: GenServer.call(process_name(id), msg)
  defp call(character_id, msg), do: GenServer.call(process_name(character_id), msg)

  defp cast(%Character{id: id}, msg), do: GenServer.cast(process_name(id), msg)
  defp cast(character_id, msg), do: GenServer.cast(process_name(character_id), msg)

  defp process_name(character_id), do: :"characters:#{character_id}"
end
