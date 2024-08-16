defmodule Ms2ex.Managers.Character do
  use GenServer

  alias Ms2ex.{Context, Packets, Schema}
  alias Ms2ex.Managers.Character

  import Ms2ex.GameHandlers.Helper.Session, only: [cleanup: 1]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def lookup(character_id), do: call(character_id, :lookup)

  # TODO avoid SQL
  def lookup_by_name(character_name) do
    case Context.Characters.get_by(name: character_name) do
      nil -> :error
      %Schema.Character{id: char_id} -> lookup(char_id)
    end
  end

  def update(%Schema.Character{} = character), do: call(character, {:update, character})

  def monitor(%Schema.Character{} = character), do: call(character, :monitor)

  def start(%Schema.Character{} = character) do
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

  # --------------------------------
  # Skills
  # --------------------------------

  def handle_call({:cast_skill, skill_cast}, _from, character) do
    character = Character.Skill.cast_skill(character, skill_cast)
    {:reply, {:ok, character}, character}
  end

  def handle_call({:add_buff, object_id, skill_cast, skill}, _from, character) do
    character = Character.Buff.add_buff(character, object_id, skill_cast, skill)
    {:reply, {:ok, character}, character}
  end

  # --------------------------------
  # Stats
  # --------------------------------

  def handle_cast({:consume_stat, stat_id, amount}, character) do
    {:noreply, Character.Stats.decrease(character, stat_id, amount)}
  end

  def handle_cast({:increase_stat, stat_id, amount}, character) do
    {:noreply, Character.Stats.increase(character, stat_id, amount)}
  end

  # --------------------------------
  # Exp
  # --------------------------------

  def handle_cast({:earn_exp, amount}, character) do
    old_lvl = character.level
    {:ok, character} = Context.Experience.maybe_add_exp(character, amount)

    if old_lvl != character.level do
      Context.Field.broadcast(character, Packets.LevelUp.bytes(character))
    end

    push(character, Packets.Experience.bytes(amount, character.exp, character.rest_exp))

    {:noreply, character}
  end

  def handle_cast({:receive_fall_dmg}, character) do
    hp = Map.get(character.stats, :health_cur)
    dmg = Context.Damage.calculate_fall_dmg(character)
    character = Character.Stats.set(character, :health, max(hp - dmg, 25))

    push(character, Packets.FallDamage.bytes(character, 0))

    {:noreply, character}
  end

  def handle_info({:regen, stat_id}, character) do
    {:noreply, Character.Stats.regen(character, stat_id)}
  end

  def handle_info({:DOWN, _, _, _pid, _reason}, character) do
    cleanup(character)
    {:stop, :normal, character}
  end

  def call(%Schema.Character{id: id}, msg) do
    if pid = Process.whereis(process_name(id)) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  def call(character_id, msg) do
    if pid = Process.whereis(process_name(character_id)) do
      GenServer.call(pid, msg)
    else
      :error
    end
  end

  def cast(%Schema.Character{id: id}, msg), do: GenServer.cast(process_name(id), msg)
  def cast(character_id, msg), do: GenServer.cast(process_name(character_id), msg)

  defp process_name(character_id) do
    :"characters:#{character_id}"
  end
end
