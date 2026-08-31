defmodule Ms2ex.Managers.Character.Revival do
  @moduledoc """
  Death and revival logic for a character.

  All health writes funnel through `Character.Stats.set`, which calls
  `check_death/1` here when health reaches 0, so every damage path is covered.
  """

  alias Ms2ex.Constants
  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Managers.Character

  import Ms2ex.Net.SenderSession, only: [push: 2]

  # daily cap for meso instant revives (the client's "uses left" gauge)
  @meso_revival_daily_max 3

  # triggers death when a stat write brings health to 0; called from
  # Character.Stats.set so every health-mutating path is covered
  @spec check_death(Schema.Character.t()) :: Schema.Character.t()
  def check_death(%{stats: %{health_cur: hp}} = character) when hp <= 0 do
    if Map.get(character, :dead?, false) do
      character
    else
      die(character)
    end
  end

  def check_death(character), do: character

  # safe revive respawns at the map spawn (or the revival return map)
  def revive(character, _type) do
    if Map.get(character, :dead?, false) do
      revive_dead(character)
    else
      character
    end
  end

  # instant revive costs mesos (level-scaled) or a free-revive coupon and
  # keeps the player in place; returns true when the payment was made so the
  # revive proceeds
  def instant_revive(character, use_voucher) do
    if Map.get(character, :dead?, false) and pay_instant_revive(character, use_voucher) do
      revive_in_place(character)
    else
      character
    end
  end

  # the client's instant-revive price (CalcRevivalMeso for non-CN) scales with
  # level on every use; the client always displays this price
  def revival_meso_cost(level, _used), do: 10_000 + max(level - 10, 0) * 1_000

  defp die(character) do
    death_count = Map.get(character, :death_count, 0) + 1
    end_tick = Ms2ex.sync_ticks() + Constants.get(:revival_penalty_tick)

    character =
      persist_revival_state(character, %{death_count: death_count, death_tick: end_tick})
      |> Map.put(:dead?, true)

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

      broadcast_revive(character)
      move_to_respawn(character)
    end
  end

  # instant revive keeps the player in place (no respawn move)
  defp revive_in_place(character) do
    max_hp = Map.get(character.stats, :health_max)
    character = Character.Stats.set(character, :health, max_hp)

    character =
      persist_revival_state(character, %{
        death_count: character.death_count,
        death_tick: 0,
        instant_revive_count: character.instant_revive_count + 1
      })
      |> Map.put(:dead?, false)

    broadcast_revive(character)

    push(character, Packets.RevivalCount.bytes(character.instant_revive_count))

    character
  end

  defp broadcast_revive(character) do
    Context.Field.broadcast(character, Packets.Revival.bytes(character.object_id))
    Context.Field.broadcast(character, Packets.ProxyGameObj.update_dead(character))
    Context.Field.remove_tombstone(character)

    push(character, Packets.Stats.set_character_stats(character))
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

  defp no_revival_here?(character) do
    Storage.Maps.get_property(character.map_id)
    |> Map.get(:no_revival_here, false)
  end

  # death penalty + the daily revive counter are persisted so a server restart
  # mid-day does not wipe them (the reference keeps these in a character-config
  # table; the daily counter is reset by a midnight worker rather than a reboot)
  defp persist_revival_state(character, attrs) do
    case Context.Characters.update(character, attrs) do
      {:ok, updated} -> updated
      _ -> character
    end
  end
end
