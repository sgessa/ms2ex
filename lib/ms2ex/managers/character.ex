defmodule Ms2ex.Managers.Character do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "characters", key: :id

  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Managers.Character
  alias Ms2ex.Types.AttributePointSource

  import Ms2ex.GameHandlers.Helper.Session, only: [cleanup: 1]
  import Ms2ex.Net.SenderSession, only: [push: 2]

  # TODO avoid SQL
  @spec lookup_by_name(String.t()) :: {:ok, Schema.Character.t()} | :error
  def lookup_by_name(character_name) do
    case Context.Characters.get_by(name: character_name) do
      nil -> :error
      %Schema.Character{id: char_id} -> call(char_id, :lookup)
    end
  end

  def start(%Schema.Character{} = character) do
    GenServer.start(__MODULE__, character, name: process_name(character.id))
  end

  # ids of every online character, from the registered character processes
  # TODO: maybe move this outside? out-of-scope
  @spec online_ids() :: [integer()]
  def online_ids do
    :erlang.registered()
    |> Enum.map(&Atom.to_string/1)
    |> Enum.filter(&String.starts_with?(&1, "characters:"))
    |> Enum.map(&String.trim_leading(&1, "characters:"))
    |> Enum.map(&String.to_integer/1)
  end

  def init(character) do
    {:ok,
     character
     |> Map.put(:regen_hp?, false)
     |> Map.put(:regen_sp?, false)
     |> Map.put(:regen_sta?, false)
     |> Map.put(:skill_cooldowns, %{})
     |> Map.update(
       :stat_point_sources,
       AttributePointSource.default_sources(),
       &AttributePointSource.normalize/1
     )
     |> Map.update(:stat_point_allocation, %{}, &Context.StatPoints.normalize_allocation/1)}
  end

  def handle_call(:lookup, _from, character) do
    {:reply, {:ok, character}, character}
  end

  def handle_call({:update, character}, _from, state) do
    updated =
      character
      |> Map.put(:skill_cooldowns, Map.get(state, :skill_cooldowns, %{}))
      |> Map.put(:stat_point_sources, state.stat_point_sources)
      |> Map.put(:stat_point_allocation, state.stat_point_allocation)
      |> Map.put(:dead?, Map.get(state, :dead?, false))
      |> Map.put(:death_count, Map.get(state, :death_count, 0))
      |> Map.put(:death_tick, Map.get(state, :death_tick, 0))
      |> Map.put(:instant_revive_count, Map.get(state, :instant_revive_count, 0))

    {:reply, :ok, updated}
  end

  def handle_call({:set_level, level}, _from, character) do
    {:ok, character} = Character.Experience.set_level(character, level)
    {:reply, {:ok, character}, character}
  end

  def handle_call(:monitor, {pid, _}, character) do
    Process.monitor(pid)
    {:reply, :ok, character}
  end

  # --------------------------------
  # Stat Points (AP)
  # --------------------------------

  def handle_call({:add_stat_point, source, amount}, _from, character) do
    case Character.StatPoints.add_stat_point(character, source, amount) do
      {:ok, character} -> {:reply, {:ok, character}, character}
      :error -> {:reply, :error, character}
    end
  end

  def handle_call({:allocate_stat_point, attribute}, _from, character) do
    case Character.StatPoints.allocate(character, attribute) do
      {:ok, character} -> {:reply, {:ok, character}, character}
      :error -> {:reply, :error, character}
    end
  end

  def handle_call(:reset_stat_points, _from, character) do
    case Character.StatPoints.reset(character) do
      {:ok, character} -> {:reply, {:ok, character}, character}
      :error -> {:reply, :error, character}
    end
  end

  # --------------------------------
  # Skills
  # --------------------------------

  def handle_call({:cast_skill, skill_cast}, _from, character) do
    {:reply, {:ok, Character.Skill.cast_skill(character, skill_cast)}, character}
  end

  def handle_call({:save_skill_cooldown, cooldown}, _from, character) do
    {:reply, :ok, Character.SkillCooldown.save(character, cooldown)}
  end

  def handle_call({:set_skill_cooldown, skill_id, level, end_tick}, _from, character) do
    {character, cooldown} = Character.SkillCooldown.set(character, skill_id, level, end_tick)
    {:reply, {:ok, cooldown}, character}
  end

  def handle_call({:get_skill_cooldowns, now}, _from, character) do
    {character, active} = Character.SkillCooldown.get_active(character, now)
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

  def handle_cast({:modify_buff_status, modifiers}, character),
    do: {:noreply, Character.Stats.modify_max(character, modifiers, :increase)}

  def handle_cast({:remove_buff_status, modifiers}, character),
    do: {:noreply, Character.Stats.modify_max(character, modifiers, :reduce)}

  def handle_cast({:increase_stats, stats}, character),
    do: {:noreply, Character.Stats.increase(character, stats)}

  def handle_cast({:decrease_stats, stats}, character),
    do: {:noreply, Character.Stats.decrease(character, stats)}

  # --------------------------------
  # Exp
  # --------------------------------

  def handle_cast({:earn_exp, amount}, character) do
    {:noreply, Character.Experience.earn_exp(character, amount)}
  end

  def handle_cast({:receive_fall_dmg, distance}, character),
    do: {:noreply, Character.FallDamage.receive_fall_damage(character, distance)}

  # --------------------------------
  # Death & revive
  # --------------------------------

  # a player dies when their health hits 0; the death is announced to the
  # field, a tombstone is raised (teammates can hit it to revive), and the
  # revival HUD is armed
  def handle_cast({:revive, type}, character),
    do: {:noreply, Character.Revival.revive(character, type)}

  def handle_cast({:revive, :instant, use_voucher}, character),
    do: {:noreply, Character.Revival.instant_revive(character, use_voucher)}

  # the daily-reset worker bulk-zeroes the DB for every character; connected
  # players also need their in-memory state cleared and the client gauge
  # refreshed
  def handle_cast(:daily_reset, character),
    do: {:noreply, Context.DailyReset.reset_character(character)}

  # triggers death when a stat write brings health to 0; called from
  # Character.Stats.set so every health-mutating path is covered
  @spec check_death(Schema.Character.t()) :: Schema.Character.t()
  def check_death(character), do: Character.Revival.check_death(character)

  def handle_info({:regen, stat_id}, character),
    do: {:noreply, Character.Stats.regen(character, stat_id)}

  def handle_info({:DOWN, _, _, _pid, _reason}, character) do
    cleanup(character)
    {:stop, :normal, character}
  end

end
