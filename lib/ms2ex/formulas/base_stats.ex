defmodule Ms2ex.Formulas.BaseStats do
  alias Ms2ex.Formulas.AttackStats
  alias Ms2ex.Storage.Tables.UserStats

  @split_level 50

  @jobs %{
    beginner: {7, 6, 2, 2, 66},
    knight: {8, 6, 2, 1, 72},
    berserker: {8, 6, 1, 2, 85},
    wizard: {1, 1, 14, 1, 60},
    priest: {1, 1, 14, 1, 66},
    archer: {6, 8, 1, 2, 61},
    heavy_gunner: {2, 8, 1, 6, 67.5},
    thief: {6, 2, 1, 8, 65},
    assassin: {2, 6, 1, 8, 60},
    rune_blade: {8, 6, 2, 1, 69},
    striker: {6, 8, 1, 2, 69},
    soul_binder: {1, 1, 14, 1, 65}
  }

  def get(job, level) do
    {strength, dexterity, intelligence, luck, hp} =
      Map.get(@jobs, job, Map.fetch!(@jobs, :beginner))

    level = max(level, 1)

    {str, dex, int, luk} =
      Enum.reduce(
        if(level > 1, do: 1..min(level - 1, @split_level - 1), else: []),
        {strength, dexterity, intelligence, luck},
        fn level, {strength, dexterity, intelligence, luck} ->
          {
            strength + str_gain(job, level),
            dexterity + dex_gain(job, level),
            intelligence + int_gain(job, level),
            luck + luck_gain(job, level)
          }
        end
      )

    {str, dex, int, luk} =
      Enum.reduce(
        if(level > @split_level, do: @split_level..(level - 1), else: []),
        {str, dex, int, luk},
        fn level, {strength, dexterity, intelligence, luck} ->
          {
            strength + post50(job, level, :str),
            dexterity + post50(job, level, :dex),
            intelligence + post50(job, level, :int),
            luck + post50(job, level, :luk)
          }
        end
      )

    health =
      50 +
        Enum.reduce(0..min(level - 1, @split_level - 1), 0.0, fn level, total ->
          total + hp * (:math.atan(0.22 * level - 1.4) / :math.pi() + 0.5)
        end) +
        Enum.reduce(
          if(level > @split_level, do: @split_level..(level - 1), else: []),
          0.0,
          fn level, total ->
            total + 11.5 + div(level - @split_level, 10) * 0.5
          end
        )

    %{
      strength: str,
      dexterity: dex,
      intelligence: int,
      luck: luk,
      health: trunc(:math.ceil(health))
    }
  end

  def all(job, level) do
    defaults = Map.merge(get(job, level), %{
      hp_regen: 10,
      hp_regen_interval: 3000,
      spirit: 100,
      sp_regen: 10,
      sp_regen_interval: 1000,
      stamina: 120,
      stamina_regen: 10,
      stamina_regen_interval: 500,
      attack_speed: 100,
      movement_speed: 100,
      accuracy: 82,
      evasion: evasion(job),
      critical_rate: critical_rate(job),
      critical_damage: 125,
      critical_evasion: 50,
      defense: max(level, 1),
      jump_height: 100,
      physical_res: physical_res(job, level),
      magical_res: magical_res(job, level),
      mount_speed: 100,
      physical_atk: 0,
      magical_atk: 0
    })

    base = Map.merge(defaults, UserStats.get(job, level) || %{})

    Map.merge(base, %{
      physical_atk: AttackStats.physical_attack(job, base.strength, base.dexterity, base.luck),
      magical_atk: AttackStats.magical_attack(job, base.intelligence)
    })
  end

  defp str_gain(job, level) do
    cond do
      job in [:beginner, :knight, :berserker, :rune_blade] -> 7
      job in [:archer, :thief] -> 1
      rem(level, 3) == 0 and job in [:wizard, :priest, :soul_binder] -> 1
      rem(level, 2) == 1 and job in [:heavy_gunner, :assassin] -> 1
      job == :striker -> 1
      true -> 0
    end
  end

  defp dex_gain(job, level) do
    cond do
      job in [:archer, :heavy_gunner, :striker] -> 7
      job in [:knight, :berserker] -> 1
      job == :beginner and rem(level, 3) != 2 -> 1
      job == :thief and rem(level, 2) == 1 -> 1
      job in [:assassin, :rune_blade] -> 1
      rem(level, 3) == 1 and job in [:wizard, :priest, :soul_binder] -> 1
      true -> 0
    end
  end

  defp int_gain(job, level) do
    cond do
      job == :beginner ->
        if(rem(level, 3) != 1, do: 1, else: 0)

      job == :knight ->
        if(rem(level, 2) == 0, do: 1, else: 0)

      job == :berserker ->
        if(rem(level, 2) == 1, do: 1, else: 0)

      job in [:wizard, :priest, :soul_binder] ->
        8

      job in [:archer, :heavy_gunner, :thief, :assassin, :rune_blade] ->
        if(rem(level, 2) == 0, do: 1, else: 0)

      job == :striker ->
        if(rem(level, 2) == 1, do: 1, else: 0)

      true ->
        0
    end
  end

  defp luck_gain(job, level) do
    cond do
      job in [:thief, :assassin] -> 7
      job == :heavy_gunner -> 1
      rem(level, 3) == 2 and job in [:wizard, :priest, :soul_binder] -> 1
      rem(level, 2) == 1 and job in [:knight, :archer, :rune_blade] -> 1
      rem(level, 2) == 0 and job in [:berserker, :striker] -> 1
      job == :beginner and rem(level, 3) != 0 -> 1
      true -> 0
    end
  end

  defp post50(job, level, stat) do
    cond do
      stat == :str and job in [:beginner, :knight, :berserker, :rune_blade] ->
        1

      stat == :dex and job in [:archer, :heavy_gunner, :striker] ->
        1

      stat == :int and job in [:wizard, :priest, :soul_binder] ->
        1

      stat == :luk and job in [:thief, :assassin] ->
        1

      stat == :luk and job == :heavy_gunner and rem(level, 3) == 0 ->
        1

      stat == :dex and job in [:knight, :berserker, :assassin, :rune_blade] and rem(level, 3) == 0 ->
        1

      stat == :str and job in [:archer, :thief, :striker] and rem(level, 3) == 0 ->
        1

      true ->
        0
    end
  end

  defp evasion(job) do
    %{
      beginner: 70,
      knight: 70,
      berserker: 72,
      wizard: 70,
      priest: 70,
      archer: 77,
      heavy_gunner: 77,
      thief: 80,
      assassin: 77,
      rune_blade: 77,
      striker: 76,
      soul_binder: 76
    }
    |> Map.get(job, 70)
  end

  defp critical_rate(job) do
    %{
      beginner: 35,
      knight: 45,
      berserker: 47,
      wizard: 40,
      priest: 45,
      archer: 55,
      heavy_gunner: 52,
      thief: 50,
      assassin: 53,
      rune_blade: 46,
      striker: 48,
      soul_binder: 48
    }
    |> Map.get(job, 35)
  end

  defp physical_res(job, level) do
    factor =
      %{
        beginner: 15.0,
        knight: 55.0,
        berserker: 55.0,
        wizard: 15.0,
        priest: 15.0,
        archer: 35.0,
        heavy_gunner: 50.0,
        thief: 15.0,
        assassin: 15.0,
        rune_blade: 55.0,
        striker: 55.0,
        soul_binder: 15.0
      }
      |> Map.get(job, 25.0)

    ceil_value(factor * max(level, 1) / 99.0)
  end

  defp magical_res(job, level) do
    factor =
      %{
        beginner: 15.0,
        knight: 15.0,
        berserker: 15.0,
        wizard: 50.0,
        priest: 55.0,
        archer: 15.0,
        heavy_gunner: 15.0,
        thief: 15.0,
        assassin: 15.0,
        rune_blade: 5.0,
        striker: 15.0,
        soul_binder: 50.0
      }
      |> Map.get(job, 25.0)

    ceil_value(factor * max(level, 1) / 99.0)
  end

  defp ceil_value(value), do: value |> :math.ceil() |> trunc()
end
