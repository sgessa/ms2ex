defmodule Ms2ex.Formulas.BaseStats do
  alias Ms2ex.Formulas.AttackStats
  alias Ms2ex.Storage.Tables.UserStats

  @split_level 50

  @dex_gain_rules %{
    archer: 7,
    heavy_gunner: 7,
    striker: 7,
    knight: 1,
    berserker: 1,
    beginner: :beginner,
    thief: :thief,
    assassin: 1,
    rune_blade: 1,
    wizard: :spellcaster,
    priest: :spellcaster,
    soul_binder: :spellcaster
  }
  @int_gain_rules %{
    beginner: :beginner,
    knight: :even,
    berserker: :odd,
    wizard: 8,
    priest: 8,
    soul_binder: 8,
    archer: :even,
    heavy_gunner: :even,
    thief: :even,
    assassin: :even,
    rune_blade: :even,
    striker: :odd
  }
  @luck_gain_rules %{
    thief: 7,
    assassin: 7,
    heavy_gunner: 1,
    wizard: :spellcaster,
    priest: :spellcaster,
    soul_binder: :spellcaster,
    knight: :odd,
    archer: :odd,
    rune_blade: :odd,
    berserker: :even,
    striker: :even,
    beginner: :beginner
  }
  @post50_rules %{
    {:str, :beginner} => :always,
    {:str, :knight} => :always,
    {:str, :berserker} => :always,
    {:str, :rune_blade} => :always,
    {:dex, :archer} => :always,
    {:dex, :heavy_gunner} => :always,
    {:dex, :striker} => :always,
    {:int, :wizard} => :always,
    {:int, :priest} => :always,
    {:int, :soul_binder} => :always,
    {:luk, :thief} => :always,
    {:luk, :assassin} => :always,
    {:luk, :heavy_gunner} => :heavy_gunner,
    {:dex, :knight} => :multiple_of_three,
    {:dex, :berserker} => :multiple_of_three,
    {:dex, :assassin} => :multiple_of_three,
    {:dex, :rune_blade} => :multiple_of_three,
    {:str, :archer} => :multiple_of_three,
    {:str, :thief} => :multiple_of_three,
    {:str, :striker} => :multiple_of_three
  }

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
    defaults =
      Map.merge(get(job, level), %{
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
    case Map.get(@dex_gain_rules, job) do
      gain when is_integer(gain) -> gain
      :beginner -> if(rem(level, 3) != 2, do: 1, else: 0)
      :thief -> if(rem(level, 2) == 1, do: 1, else: 0)
      :spellcaster -> if(rem(level, 3) == 1, do: 1, else: 0)
      _ -> 0
    end
  end

  defp int_gain(job, level) do
    case Map.get(@int_gain_rules, job) do
      gain when is_integer(gain) -> gain
      :beginner -> if(rem(level, 3) != 1, do: 1, else: 0)
      :even -> if(rem(level, 2) == 0, do: 1, else: 0)
      :odd -> if(rem(level, 2) == 1, do: 1, else: 0)
      _ -> 0
    end
  end

  defp luck_gain(job, level) do
    luck_gain_for_rule(Map.get(@luck_gain_rules, job), level)
  end

  defp luck_gain_for_rule(7, _level), do: 7
  defp luck_gain_for_rule(1, _level), do: 1
  defp luck_gain_for_rule(:spellcaster, level), do: parity_gain(level, 3, 2)
  defp luck_gain_for_rule(:odd, level), do: parity_gain(level, 2, 1)
  defp luck_gain_for_rule(:even, level), do: parity_gain(level, 2, 0)
  defp luck_gain_for_rule(:beginner, level), do: if(rem(level, 3) != 0, do: 1, else: 0)
  defp luck_gain_for_rule(_, _level), do: 0

  defp parity_gain(level, divisor, remainder),
    do: if(rem(level, divisor) == remainder, do: 1, else: 0)

  defp post50(job, level, stat) do
    case Map.get(@post50_rules, {stat, job}) do
      :always -> 1
      :heavy_gunner -> if(rem(level, 3) == 0, do: 1, else: 0)
      :multiple_of_three -> if(rem(level, 3) == 0, do: 1, else: 0)
      _ -> 0
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
