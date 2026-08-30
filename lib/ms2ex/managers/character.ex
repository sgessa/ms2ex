defmodule Ms2ex.Managers.Character do
  use GenServer

  alias Ms2ex.Context
  alias Ms2ex.Constants
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
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

  @spec set_level(Schema.Character.t(), integer()) :: {:ok, Schema.Character.t()} | :error
  def set_level(%Schema.Character{} = character, level) do
    call(character, {:set_level, level})
  end

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
    updated =
      character
      |> Map.put(:skill_cooldowns, Map.get(state, :skill_cooldowns, %{}))
      |> Map.put(:dead?, Map.get(state, :dead?, false))
      |> Map.put(:death_count, Map.get(state, :death_count, 0))
      |> Map.put(:death_tick, Map.get(state, :death_tick, 0))
      |> Map.put(:instant_revive_count, Map.get(state, :instant_revive_count, 0))

    {:reply, :ok, updated}
  end

  def handle_call({:set_level, level}, _from, character) do
    level = level |> max(1) |> min(Constants.get(:character_max_level))
    old_level = character.level
    {:ok, character} = Context.Characters.update(character, %{exp: 0, level: level})
    character = refresh_level(character, old_level)

    {:reply, {:ok, character}, character}
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
    {:noreply, character |> Character.Stats.decrease(stat_id, amount) |> maybe_die()}
  end

  def handle_cast({:set_stat, stat_id, amount}, character) do
    {:noreply, character |> Character.Stats.set(stat_id, amount) |> maybe_die()}
  end

  def handle_cast({:modify_buff_status, modifiers}, character) do
    character =
      Enum.reduce(modifiers, character, fn {stat, amount}, character ->
        Character.Stats.modify_max(character, stat, amount)
      end)

    {:noreply, character}
  end

  def handle_cast({:remove_buff_status, modifiers}, character) do
    character =
      Enum.reduce(modifiers, character, fn {stat, amount}, character ->
        Character.Stats.modify_max(character, stat, -amount)
      end)

    {:noreply, character}
  end

  def handle_cast({:increase_stats, stats}, character) do
    character =
      Enum.reduce(stats, character, fn {stat, amount}, character ->
        Character.Stats.increase(character, stat, amount)
      end)

    {:noreply, character}
  end

  def handle_cast({:decrease_stats, stats}, character) do
    character =
      Enum.reduce(stats, character, fn {stat, amount}, character ->
        Character.Stats.decrease(character, stat, amount)
      end)

    {:noreply, maybe_die(character)}
  end

  # --------------------------------
  # Exp
  # --------------------------------

  def handle_cast({:earn_exp, amount}, character) do
    old_lvl = character.level
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    {:ok, character} = Context.Experience.maybe_add_exp(character, amount)
    character = refresh_level(character, old_lvl)

    push(character, Packets.Experience.bytes(amount, character.exp, character.rest_exp))

    {:noreply, Map.put(character, :skill_cooldowns, cooldowns)}
  end

  def handle_cast({:receive_fall_dmg, distance}, character) do
    hp = Map.get(character.stats, :health_cur)
    dmg = Context.Damage.calculate_fall_dmg(character, distance)
    character = character |> Character.Stats.set(:health, hp - dmg) |> maybe_die()

    push(character, Packets.FallDamage.bytes(character, dmg))

    {:noreply, character}
  end

  # --------------------------------
  # Death & revive
  # --------------------------------

  # daily cap for meso instant revives (the client's "uses left" gauge)
  @meso_revival_daily_max 3

  # a player dies when their health hits 0; the death is announced to the
  # field, a tombstone is raised (teammates can hit it to revive), and the
  # revival HUD is armed
  def handle_cast({:revive, type}, character) do
    {:noreply, revive(character, type)}
  end

  def handle_cast({:revive, :instant, use_voucher}, character) do
    character =
      if Map.get(character, :dead?, false) and pay_instant_revive(character, use_voucher) do
        instant_revive(character)
      else
        character
      end

    {:noreply, character}
  end

  # the daily-reset worker zeroes the meso instant-revive allowance for every
  # character; connected players also need their in-memory counter cleared and
  # the client gauge refreshed
  def handle_cast(:reset_daily_revives, character) do
    character = Map.put(character, :instant_revive_count, 0)
    push(character, Packets.RevivalCount.bytes(0))
    {:noreply, character}
  end

  defp maybe_die(%{stats: %{health_cur: hp}} = character) when hp <= 0 do
    if Map.get(character, :dead?, false) do
      character
    else
      die(character)
    end
  end

  defp maybe_die(character), do: character

  defp die(character) do
    death_count = Map.get(character, :death_count, 0) + 1
    end_tick = Ms2ex.sync_ticks() + Constants.get(:revival_penalty_tick)

    character =
      character
      |> Map.put(:dead?, true)
      |> Map.put(:death_count, death_count)
      |> Map.put(:death_tick, end_tick)

    persist_revival_state(character)

    dark_tomb = only_dark_tomb?(character) or death_count > 1

    Context.Field.broadcast(character, Packets.DeadUser.bytes(character.object_id, dark_tomb))
    Context.Field.broadcast(character, Packets.ProxyGameObj.update_dead(character))

    Context.Field.add_tombstone(character)

    push(character, Packets.RevivalCount.bytes(Map.get(character, :instant_revive_count, 0)))
    push(character, Packets.RevivalConfirm.bytes(character.object_id, end_tick, death_count))

    # the corpse no longer carries its buffs
    Context.Field.remove_owner_buffs(character)

    character
  end

  # safe revive respawns at the map spawn (or the revival return map); the
  # instant variant stays in place and costs mesos
  defp revive(character, _type) do
    if Map.get(character, :dead?, false) do
      revive_dead(character)
    else
      character
    end
  end

  defp revive_dead(character) do
    if no_revival_here?(character) do
      character
    else
      max_hp = Map.get(character.stats, :health_max)
      character = Character.Stats.set(character, :health, max_hp)

      character =
        character
        |> Map.put(:dead?, false)
        |> Map.put(:death_tick, 0)

      Context.Field.broadcast(character, Packets.Revival.bytes(character.object_id))
      Context.Field.broadcast(character, Packets.ProxyGameObj.update_dead(character))
      Context.Field.remove_tombstone(character)

      push(character, Packets.Stats.set_character_stats(character))

      move_to_respawn(character)
    end
  end

  # instant revive costs mesos (level-scaled) or a free-revive coupon; returns
  # true when the payment was made so the revive proceeds
  defp pay_instant_revive(character, use_voucher) do
    if use_voucher do
      # TODO consume a FreeReviveCoupon item from the inventory
      false
    else
      used = Map.get(character, :instant_revive_count, 0)

      if used < @meso_revival_daily_max do
        cost = revival_meso_cost(character.level, used)

        # only revive once the mesos were actually deducted
        enough_mesos?(character, cost) &&
          match?({:ok, _}, Context.Wallets.update(character, :mesos, -cost))
      else
        false
      end
    end
  end

  # instant revive keeps the player in place (no respawn move)
  defp instant_revive(character) do
    max_hp = Map.get(character.stats, :health_max)
    character = Character.Stats.set(character, :health, max_hp)

    character =
      character
      |> Map.put(:dead?, false)
      |> Map.put(:death_tick, 0)
      |> Map.update!(:instant_revive_count, &(&1 + 1))

    persist_revival_state(character)

    Context.Field.broadcast(character, Packets.Revival.bytes(character.object_id))
    Context.Field.broadcast(character, Packets.ProxyGameObj.update_dead(character))
    Context.Field.remove_tombstone(character)

    push(character, Packets.Stats.set_character_stats(character))
    push(character, Packets.RevivalCount.bytes(character.instant_revive_count))

    character
  end

  # the client's instant-revive price (CalcRevivalMeso for non-CN): the first
  # meso revive of the day is flat, later ones scale with level
  def revival_meso_cost(_level, 1), do: 10_000
  def revival_meso_cost(level, _used), do: 10_000 + max(level - 10, 0) * 1_000

  defp enough_mesos?(character, cost) do
    case Context.Wallets.find(character) do
      %Schema.Wallet{mesos: mesos} -> mesos >= cost
      _ -> false
    end
  end

  defp move_to_respawn(character) do
    return_map_id = Storage.Maps.get_revival_return_id(character.map_id)

    if return_map_id != 0 and return_map_id != character.map_id do
      Context.Field.change_field(character, return_map_id)
      character
    else
      spawn_point = Storage.Maps.get_spawn(character.map_id)

      character =
        character
        |> Map.put(:position, spawn_point.position)
        |> Map.put(:rotation, spawn_point.rotation)

      push(character, Packets.MoveCharacter.bytes(character, spawn_point.position))
      Context.Field.broadcast(character, Packets.ProxyGameObj.update_player(character))
      character
    end
  end

  defp only_dark_tomb?(character) do
    Storage.Maps.get_property(character.map_id)
    |> Map.get(:only_dark_tomb, false)
  end

  # death penalty + the daily revive counter are persisted so a server restart
  # mid-day does not wipe them (the reference keeps these in a character-config
  # table; the daily counter is reset by a midnight worker rather than a reboot)
  defp persist_revival_state(character) do
    Context.Characters.update(character, %{
      death_count: character.death_count,
      death_tick: character.death_tick,
      instant_revive_count: character.instant_revive_count
    })

    character
  end

  defp no_revival_here?(character) do
    Storage.Maps.get_property(character.map_id)
    |> Map.get(:no_revival_here, false)
  end

  def handle_info({:regen, stat_id}, character) do
    character =
      if Map.get(character, :dead?, false) do
        Map.put(character, :"regen_#{stat_id}?", false)
      else
        Character.Stats.regen(character, stat_id)
      end

    {:noreply, character}
  end

  def handle_info({:DOWN, _, _, _pid, _reason}, character) do
    cleanup(character)
    {:stop, :normal, character}
  end

  defp refresh_level(character, old_level) do
    if old_level != character.level do
      character = Context.ItemStats.apply(character)
      Context.Field.broadcast(character, Packets.LevelUp.bytes(character))
      Context.Field.broadcast_stats(character)
      character
    else
      character
    end
  end

  defp process_name(character_id) do
    :"characters:#{character_id}"
  end
end
