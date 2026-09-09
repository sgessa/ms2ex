defmodule Ms2ex.Storage.Tables.Guild do
  @moduledoc """
  `guild.xml`: Guild metadata containing buffs, houses, npcs, and properties.
  """

  alias Ms2ex.Storage

  @table_name "guild.xml"

  def all do
    case Storage.get(:table, @table_name) do
      nil -> %{}
      doc -> Map.get(doc, :table, %{})
    end
  end

  def properties do
    Map.get(all(), :properties, %{})
  end

  def get_property(level) when is_integer(level) do
    Map.get(properties(), level)
  end

  @doc """
  Finds the property corresponding to the given guild experience.
  Picks the highest level whose cumulative required experience <= current exp.
  """
  def property_for_exp(exp) when is_integer(exp) do
    props = properties()

    if map_size(props) == 0 do
      default_property()
    else
      props
      |> Map.values()
      |> Enum.filter(&(&1.experience <= exp))
      |> Enum.max_by(& &1.level, fn -> default_property() end)
    end
  end

  def get_buff(buff_id, level) do
    all()
    |> get_in([:buffs, buff_id, level])
  end

  def get_house(rank, theme) do
    all()
    |> get_in([:houses, rank, theme])
  end

  def get_npc(type, level) do
    all()
    |> get_in([:npcs, type, level])
  end

  def default_property do
    %{
      level: 1,
      experience: 0,
      capacity: 60,
      fund_max: 10_000_000,
      donate_max: 10,
      check_in_exp: 10,
      check_in_fund: 1000,
      check_in_coin: 1,
      check_in_player_exp_rate: 0.05,
      donate_coin: 1,
      donate_player_exp_rate: 0.05,
      win_mini_game_exp: 50,
      lose_mini_game_exp: 10,
      win_mini_game_fund: 5000,
      lose_mini_game_fund: 1000,
      win_mini_game_coin: 5,
      lose_mini_game_coin: 1,
      raid_exp: 100,
      raid_fund: 10_000
    }
  end
end
