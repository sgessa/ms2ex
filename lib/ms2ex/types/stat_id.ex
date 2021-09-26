defmodule Ms2ex.StatId do
  import EctoEnum

  defenum(Type,
    str: 0x00,
    dex: 0x01,
    int: 0x02,
    luk: 0x03,
    hp: 0x04,
    hp_regen: 0x05,
    hp_regen_time: 0x06,
    sp: 0x07,
    sp_regen: 0x08,
    sp_regen_time: 0x09,
    sta: 0x0A,
    sta_regen: 0x0B,
    sta_regen_time: 0x0C,
    attk_speed: 0x0D,
    mov_speed: 0x0E,
    accuracy: 0x0F,
    evasion: 0x10,
    crit_rate: 0x11,
    crit_dmg: 0x12,
    crit_evasion: 0x13,
    def: 0x14,
    guard: 0x15,
    jump_height: 0x16,
    phys_attk: 0x17,
    magic_attk: 0x18,
    phys_res: 0x19,
    magic_res: 0x1A,
    min_attk: 0x1B,
    max_attk: 0x1C,
    min_dmg: 0x1D,
    max_dmg: 0x1E,
    pierce: 0x1F,
    mount_speed: 0x20,
    bonus_attk: 0x21,
    pet_bonus_attk: 0x22
  )

  def list() do
    Keyword.keys(Type.__enum_map__())
  end

  def from_id(id) do
    Type.__enum_map__()
    |> Enum.find(fn {_k, v} -> v == id end)
    |> elem(0)
  end

  def from_name(name), do: Type.__enum_map__()[name]
end
