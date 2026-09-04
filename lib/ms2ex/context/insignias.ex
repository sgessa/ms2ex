defmodule Ms2ex.Context.Insignias do
  @moduledoc """
  Name tag symbols. Each insignia is gated on a condition the wearer has to
  keep meeting, so the symbol is only drawn while the condition holds.
  """

  alias Ms2ex.Managers
  alias Ms2ex.Schema
  alias Ms2ex.Storage

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
           Ms2ex.Context.PremiumMemberships.get(character.account_id),
         false <- Ms2ex.Context.PremiumMemberships.expired?(membership) do
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
    Enum.sum(character.trophies) >= 1000
  end

  def display?(character, %{type: :title, title_id: title_id}) do
    character
    |> Ms2ex.Context.Characters.list_titles()
    |> Enum.member?(title_id)
  end

  def display?(character, %{type: :adventure_level}), do: character.prestige_level >= 100

  def display?(_character, _metadata), do: false
end
