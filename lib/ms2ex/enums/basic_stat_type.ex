defmodule Ms2ex.Enums.BasicStatType do
  use Ms2ex.Enum, %{
    strength: 0,
    dexterity: 1,
    intelligence: 2,
    luck: 3,
    health: 4,
    hp_regen: 5,
    hp_regen_interval: 6,
    spirit: 7,
    sp_regen: 8,
    sp_regen_interval: 9,
    stamina: 10,
    stamina_regen: 11,
    stamina_regen_interval: 12,
    attack_speed: 13,
    movement_speed: 14,
    accuracy: 15,
    evasion: 16,
    critical_rate: 17,
    critical_damage: 18,
    critical_evasion: 19,
    defense: 20,
    perfect_guard: 21,
    jump_height: 22,
    physical_atk: 23,
    magical_atk: 24,
    physical_res: 25,
    magical_res: 26,
    min_weapon_atk: 27,
    max_weapon_atk: 28,
    damage: 29,
    unknown: 30,
    piercing: 31,
    mount_speed: 32,
    bonus_atk: 33,
    pet_bonus_atk: 34
  }

  def ordered_keys() do
    values()
    |> Enum.sort()
    |> Enum.map(&get_key(&1))
  end
end
