defmodule Ms2ex.Enums.SkillEntity do
  use Ms2ex.Enum, %{
    none: 0,
    target: 1,
    owner: 2,
    caster: 3,
    pet_owner: 4,
    attacker: 5,
    region_buff: 6,
    region_debuff: 7,
    region_pet: 8
  }
end
