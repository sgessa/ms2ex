defmodule Ms2ex.Context.Buffs do
  @moduledoc """
  Buffs that outlive the field they were cast in.

  Effects whose metadata does not clear them on logout are stored with an
  absolute expiry, so purchased or long-running effects survive map changes,
  channel switches and relogs. Expiry is wall-clock because the tick base
  they run on is per-VM and resets with the server.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ecto.Query

  @type stored :: %{
          effect_id: integer(),
          effect_level: integer(),
          stacks: integer(),
          remaining_ms: integer()
        }

  @doc """
  Whether an effect should be carried across sessions. Mirrors the reference's
  `RemoveOnLogout` check.
  """
  @spec persist?(integer(), integer()) :: boolean()
  def persist?(effect_id, effect_level) do
    case Storage.Skills.get_effect(effect_id, effect_level) do
      %{property: %{remove_on_logout: remove?}} -> not remove?
      _ -> false
    end
  end

  @doc """
  Replaces the character's stored buffs with the ones still running on the
  field they are leaving.
  """
  @spec save(integer(), [map()]) :: :ok
  def save(character_id, buffs) do
    now = DateTime.utc_now()
    tick = Ms2ex.sync_ticks()

    entries =
      buffs
      |> Enum.filter(&persist?(&1.skill.id, &1.skill.level))
      |> Enum.flat_map(&entry(&1, character_id, now, tick))
      |> Enum.uniq_by(& &1.effect_id)

    Repo.transaction(fn ->
      Schema.CharacterBuff
      |> where([b], b.character_id == ^character_id)
      |> Repo.delete_all()

      Repo.insert_all(Schema.CharacterBuff, entries)
    end)

    :ok
  end

  @doc """
  Stored buffs with their remaining duration in milliseconds; expired rows are
  skipped.
  """
  @spec load(integer()) :: [stored()]
  def load(character_id) do
    now = DateTime.utc_now()

    Schema.CharacterBuff
    |> where([b], b.character_id == ^character_id)
    |> Repo.all()
    |> Enum.flat_map(fn buff ->
      remaining = DateTime.diff(buff.expires_at, now, :millisecond)

      if remaining > 0 do
        [
          %{
            effect_id: buff.effect_id,
            effect_level: buff.effect_level,
            stacks: buff.stacks,
            remaining_ms: remaining
          }
        ]
      else
        []
      end
    end)
  end

  @doc "Drops every stored buff for a character."
  @spec clear(integer()) :: :ok
  def clear(character_id) do
    Schema.CharacterBuff
    |> where([b], b.character_id == ^character_id)
    |> Repo.delete_all()

    :ok
  end

  defp entry(buff, character_id, now, tick) do
    remaining = buff.end_tick - tick
    timestamp = DateTime.truncate(now, :second)

    if remaining > 0 do
      [
        %{
          character_id: character_id,
          effect_id: buff.skill.id,
          effect_level: buff.skill.level,
          stacks: buff.stacks,
          expires_at: DateTime.add(now, remaining, :millisecond),
          inserted_at: timestamp,
          updated_at: timestamp
        }
      ]
    else
      []
    end
  end
end
