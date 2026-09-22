defmodule Ms2ex.Managers.Field.BattleStance do
  @moduledoc """
  The player battle stance (weapon drawn) and its quiet-window expiry. The
  client renders a player's weapon in hand only while the player is in the
  battle state, which the server signals with the UserBattle packet on every
  stance change (see `Packets.UserBattle`).

  The field owns one deadline per character (`:battle_stances`): every
  in-battle cast re-stamps it, the stance holds through continuous combat,
  and it drops once a window passes without a cast.
  """

  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @default_duration_ms 5_000

  @doc """
  Arms (or re-stamps) the character's battle-stance deadline. Every
  in-battle cast re-stamps it, so the stance holds through continuous
  combat and only drops after a quiet window since the last cast.
  """
  def arm(state, %Schema.Character{} = character) do
    stances = Map.get(state, :battle_stances, %{})

    entry =
      case Map.get(stances, character.id) do
        %{timer: timer} = entry ->
          %{entry | character: character, cast_at: Ms2ex.sync_ticks(), timer: timer}

        nil ->
          %{character: character, cast_at: Ms2ex.sync_ticks(), timer: nil}
      end

    state = Map.put(state, :battle_stances, Map.put(stances, character.id, entry))
    schedule_drop(state, character.id)
  end

  @doc """
  Drops the battle stance once the character's quiet window has passed:
  stays scheduled while casts keep the deadline in the future, leaves
  (broadcasting the sheathe) once the window closed.
  """
  def drop(state, character_id) do
    case get_in(state, [:battle_stances, character_id]) do
      nil ->
        {:stay, state}

      entry ->
        state = put_in(state, [:battle_stances, character_id, :timer], nil)
        remaining = entry.cast_at + duration() - Ms2ex.sync_ticks()

        if remaining > 0 do
          {:stay, schedule_drop(state, character_id, remaining)}
        else
          Ms2ex.Managers.Field.Character.leave_battle_stance(entry.character)
          state = Map.update!(state, :battle_stances, &Map.delete(&1, character_id))
          {:leave, state}
        end
    end
  end

  # one pending drop check per character: arming with a check already
  # pending only re-stamps the deadline; the fired check reschedules itself
  # for the remaining window instead
  defp schedule_drop(state, character_id, within \\ nil) do
    entry = get_in(state, [:battle_stances, character_id])

    if entry && entry.timer == nil do
      within = within || duration()
      ref = Process.send_after(self(), {:battle_stance_drop, character_id}, max(within, 0))
      put_in(state, [:battle_stances, character_id, :timer], ref)
    else
      state
    end
  end

  defp duration do
    Storage.Tables.Constants.get(:user_battle_duration_tick) || @default_duration_ms
  end
end
