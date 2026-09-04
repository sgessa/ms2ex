defmodule Ms2ex.Context.Insignias do
  @moduledoc """
  Name tag symbols. Each insignia is gated on a condition the wearer has to
  keep meeting, so the symbol is only drawn while the condition holds.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  require Logger

  @doc """
  Wears an insignia: persists it, swaps the buff the previous one granted for
  the new one and reports whether the symbol should be drawn.

  `force: true` displays and grants the insignia regardless of its condition,
  for the admin command.
  """
  @spec equip(Schema.Character.t(), integer(), keyword()) ::
          {:ok, Schema.Character.t(), boolean()} | :error
  def equip(%Schema.Character{} = character, insignia_id, opts \\ []) do
    case Storage.Tables.Insignias.get(insignia_id) do
      {:ok, metadata} ->
        worn = character.insignia_id
        display = Keyword.get(opts, :force, false) or display?(character, metadata)

        {:ok, character} = Context.Characters.update(character, %{insignia_id: insignia_id})
        Managers.Character.call(character, {:update, character})

        # the buff swap has to follow the character write: {:update, ...}
        # replaces the manager's state wholesale and would discard the stat
        # change the removal makes
        remove_buff(character, worn)
        if display, do: apply_buff(character, metadata)

        {:ok, character, display}

      :error ->
        :error
    end
  end

  @doc """
  Whether the character's current insignia should be drawn above their head.
  """
  @spec display?(Schema.Character.t()) :: boolean()
  def display?(%Schema.Character{} = character) do
    case Storage.Tables.Insignias.get(character.insignia_id) do
      {:ok, metadata} -> display?(character, metadata)
      :error -> false
    end
  end

  @doc """
  Whether the character meets an insignia's condition.
  """
  @spec display?(Schema.Character.t(), map()) :: boolean()
  def display?(character, %{type: :vip}) do
    with %Schema.PremiumMembership{} = membership <-
           Context.PremiumMemberships.get(character.account_id),
         false <- Context.PremiumMemberships.expired?(membership) do
      true
    else
      _ -> false
    end
  end

  def display?(character, %{type: :level}), do: character.level >= 50

  def display?(character, %{type: :enchant}) do
    character
    |> Managers.Inventory.list_equips()
    |> Enum.any?(&(&1.inventory_tab == :gear and &1.enchant_level >= 12 and &1.rarity > 3))
  end

  def display?(character, %{type: :trophy_point}) do
    case Managers.Achievement.trophy_counts(character) do
      [combat, adventure, lifestyle] -> combat + adventure + lifestyle >= 1000
      _ -> false
    end
  end

  def display?(character, %{type: :title, title_id: title_id}) do
    character
    |> Context.Characters.list_titles()
    |> Enum.member?(title_id)
  end

  def display?(character, %{type: :adventure_level}), do: character.prestige_level >= 100

  def display?(_character, %{type: :none}), do: false

  def display?(_character, %{type: type}) do
    Logger.info("Unhandled insignia condition type: #{type}")
    false
  end

  def display?(_character, _metadata), do: false

  # the insignia the player was wearing keeps its buff until it is swapped out
  defp remove_buff(character, worn) do
    with {:ok, %{buff_id: buff_id}} <- Storage.Tables.Insignias.get(worn),
         true <- buff_id > 0 do
      Context.Field.remove_effect_buff(character, buff_id)
    else
      _ -> :ok
    end
  end

  # the buff itself lives in the field's state and the field replies :ok,
  # so the response carries nothing worth keeping
  defp apply_buff(character, %{buff_id: buff_id, buff_level: buff_level}) when buff_id > 0 do
    Context.Field.call(character, {:add_effect_buff, buff_id, buff_level, character})
    :ok
  end

  defp apply_buff(_character, _metadata), do: :ok
end
