defmodule Ms2ex.Managers.Character do
  use GenServer

  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Managers.Character

  import Ms2ex.GameHandlers.Helper.Session, only: [cleanup: 1]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @spec lookup(integer()) :: {:ok, Schema.Character.t()} | :error
  def lookup(character_id), do: call(character_id, :lookup)

  # TODO avoid SQL
  @spec lookup_by_name(String.t()) :: {:ok, Schema.Character.t()} | :error
  def lookup_by_name(character_name) do
    case Context.Characters.get_by(name: character_name) do
      nil -> :error
      %Schema.Character{id: char_id} -> lookup(char_id)
    end
  end

  @spec update(Schema.Character.t()) :: :ok | :error
  def update(%Schema.Character{} = character), do: call(character, {:update, character})

  @spec save_skill_cooldown(Schema.Character.t(), map()) :: :ok | :error
  def save_skill_cooldown(%Schema.Character{} = character, cooldown) do
    call(character, {:save_skill_cooldown, cooldown})
  end

  @spec set_skill_cooldown(Schema.Character.t(), integer(), integer(), integer()) ::
          {:ok, map()} | :error
  def set_skill_cooldown(%Schema.Character{} = character, skill_id, level, end_tick) do
    call(character, {:set_skill_cooldown, skill_id, level, end_tick})
  end

  @spec get_skill_cooldowns(integer()) :: {:ok, [map()]} | :error
  def get_skill_cooldowns(character_id) do
    call(character_id, {:get_skill_cooldowns, Ms2ex.sync_ticks()})
  end

  def monitor(%Schema.Character{} = character), do: call(character, :monitor)

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

  def start(%Schema.Character{} = character) do
    GenServer.start(__MODULE__, character, name: process_name(character.id))
  end

  def init(character) do
    {:ok,
     character
     |> Map.put(:regen_hp?, false)
     |> Map.put(:regen_sp?, false)
     |> Map.put(:regen_sta?, false)
     |> Map.put(:skill_cooldowns, %{})}
  end

  def handle_call(:lookup, _from, character) do
    {:reply, {:ok, character}, character}
  end

  def handle_call({:update, character}, _from, state) do
    {:reply, :ok, Map.put(character, :skill_cooldowns, Map.get(state, :skill_cooldowns, %{}))}
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

  def handle_call({:save_skill_cooldown, cooldown}, _from, character) do
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    existing = Map.get(cooldowns, cooldown.skill_id)

    cooldown =
      if is_nil(existing) or cooldown.start_tick > existing.end_tick do
        %{
          skill_id: cooldown.skill_id,
          level: cooldown.level,
          group_id: cooldown.group_id,
          end_tick: cooldown.end_tick,
          recharge_max_count: cooldown.recharge_max_count,
          charges: 0
        }
      else
        existing
      end

    cooldown =
      if cooldown.recharge_max_count > 0 do
        %{cooldown | charges: min(cooldown.charges + 1, cooldown.recharge_max_count)}
      else
        cooldown
      end

    character =
      Map.put(character, :skill_cooldowns, Map.put(cooldowns, cooldown.skill_id, cooldown))

    {:reply, :ok, character}
  end

  def handle_call({:set_skill_cooldown, skill_id, level, end_tick}, _from, character) do
    cooldown = %{
      skill_id: skill_id,
      level: level,
      group_id: 0,
      end_tick: end_tick,
      recharge_max_count: 0,
      charges: 0
    }

    character =
      Map.put(
        character,
        :skill_cooldowns,
        Map.put(Map.get(character, :skill_cooldowns, %{}), skill_id, cooldown)
      )

    {:reply, {:ok, cooldown}, character}
  end

  def handle_call({:get_skill_cooldowns, now}, _from, character) do
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    active = Map.values(cooldowns) |> Enum.filter(&(&1.end_tick > now))

    character =
      Map.put(
        character,
        :skill_cooldowns,
        Map.filter(cooldowns, fn {_id, cooldown} -> cooldown.end_tick > now end)
      )

    {:reply, {:ok, active}, character}
  end

  # --------------------------------
  # Stats
  # --------------------------------

  def handle_cast({:consume_stat, stat_id, amount}, character) do
    {:noreply, Character.Stats.decrease(character, stat_id, amount)}
  end

  def handle_cast({:set_stat, stat_id, amount}, character) do
    {:noreply, Character.Stats.set(character, stat_id, amount)}
  end

  def handle_cast({:increase_stat, stat_id, amount}, character) do
    {:noreply, Character.Stats.increase(character, stat_id, amount)}
  end

  # --------------------------------
  # Exp
  # --------------------------------

  def handle_cast({:earn_exp, amount}, character) do
    old_lvl = character.level
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    {:ok, character} = Context.Experience.maybe_add_exp(character, amount)

    if old_lvl != character.level do
      Context.Field.broadcast(character, Packets.LevelUp.bytes(character))
    end

    push(character, Packets.Experience.bytes(amount, character.exp, character.rest_exp))

    {:noreply, Map.put(character, :skill_cooldowns, cooldowns)}
  end

  def handle_cast({:receive_fall_dmg, distance}, character) do
    hp = Map.get(character.stats, :health_cur)
    dmg = Context.Damage.calculate_fall_dmg(character, distance)
    character = Character.Stats.set(character, :health, hp - dmg)

    push(character, Packets.FallDamage.bytes(character, dmg))

    {:noreply, character}
  end

  def handle_info({:regen, stat_id}, character) do
    {:noreply, Character.Stats.regen(character, stat_id)}
  end

  def handle_info({:DOWN, _, _, _pid, _reason}, character) do
    cleanup(character)
    {:stop, :normal, character}
  end

  defp process_name(character_id) do
    :"characters:#{character_id}"
  end
end
