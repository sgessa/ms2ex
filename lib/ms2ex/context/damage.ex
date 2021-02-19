defmodule Ms2ex.Damage do
  alias Ms2ex.{Character, Characters, Metadata.Npc}

  import Access, only: [key!: 1]

  def calculate(%Character{}, %Npc{}) do
    crit_rate_pct = 40
    dmg = 9_999_999
    is_critical = Enum.random(0..100) <= crit_rate_pct
    %{dmg: dmg, is_critical: is_critical}
  end

  def apply_damage(%Npc{stats: %{hp: hp}} = npc, %{dmg: dmg} = damage) do
    hp = ensure_positive_health(hp.max - dmg)

    npc =
      npc
      |> update_health(hp)
      |> Map.put(:damage, damage)

    if npc.stats.hp.max <= 0 do
      {:dead, %{npc | dead?: true}}
    else
      {:alive, npc}
    end
  end

  def receive_fall_dmg(%Character{stats: %{current_hp_min: hp}} = character) do
    dmg = calculate_fall_dmg(character)
    hp = ensure_positive_health(hp - dmg, 25)
    update_health(character, hp)
  end

  @fall_dmg 150
  defp calculate_fall_dmg(%Character{position: %{z: _height}}) do
    @fall_dmg
  end

  defp update_health(%Character{stats: stats} = character, health) do
    stats = Map.delete(stats, :__struct__)
    stats = %{stats | current_hp_min: health}
    {:ok, character} = Characters.update(character, %{stats: stats})
    character
  end

  defp update_health(obj, health) do
    update_in(obj, [key!(:stats), key!(:hp), key!(:max)], fn _ -> health end)
  end

  defp ensure_positive_health(health, min \\ 0), do: if(health < 0, do: min, else: health)
end
