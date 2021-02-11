defmodule Ms2ex.Damage do
  alias Ms2ex.{Character, Metadata.Npc}

  import Access, only: [key!: 1]

  def calculate(%Character{}, %Npc{}) do
    crit_rate_pct = 40
    dmg = 999_999_999
    is_critical = Enum.random(0..100) <= crit_rate_pct
    %{dmg: dmg, is_critical: is_critical}
  end

  def apply_damage(%Npc{} = npc, %{dmg: dmg} = damage) do
    npc =
      npc
      |> update_in([key!(:stats), key!(:hp), key!(:total)], &(&1 - dmg))
      |> Map.put(:damage, damage)

    if npc.stats.hp.total <= 0 do
      {:dead, npc}
    else
      {:alive, npc}
    end
  end
end
