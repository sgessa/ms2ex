defmodule Ms2ex.Formulas.BaseStats do
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
      job == :newbie and rem(level, 3) != 2 -> 1
      job == :thief and rem(level, 2) == 1 -> 1
      job in [:assassin, :rune_blade] -> 1
      rem(level, 3) == 1 and job in [:wizard, :priest, :soul_binder] -> 1
      true -> 0
    end
  end

  defp int_gain(job, level),
    do:
      if(job in [:wizard, :priest, :soul_binder],
        do: 8,
        else: if(job == :berserker or rem(level, 2) == 0, do: 1, else: 0)
      )

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
end
