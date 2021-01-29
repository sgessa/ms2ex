defmodule Ms2ex.CharacterStats do
  use Ecto.Schema

  import Ecto.Changeset

  @stats [
    :str,
    :dex,
    :int,
    :luk,
    :hp,
    :current_hp,
    :hp_regen,
    :unknown7,
    :spirit,
    :unknown9,
    :unknown10,
    :stamina,
    :unknown12,
    :unknown13,
    :attk_speed,
    :mov_speed,
    :accuracy,
    :evasion,
    :crit_rate,
    :crit_dmg,
    :crit_evasion,
    :def,
    :guard,
    :jump_height,
    :phys_attk,
    :magic_attk,
    :phys_res,
    :magic_res,
    :min_attk,
    :max_attk,
    :unknown30,
    :unknown31,
    :pierce,
    :mount_speed,
    :bonus_attk,
    :unknown35
  ]

  schema "character_stats" do
    belongs_to :character, Ms2ex.Character

    field :str_total, :integer, default: 100
    field :str_min, :integer, default: 0
    field :str_max, :integer, default: 100

    field :dex_total, :integer, default: 100
    field :dex_min, :integer, default: 0
    field :dex_max, :integer, default: 100

    field :int_total, :integer, default: 100
    field :int_min, :integer, default: 0
    field :int_max, :integer, default: 100

    field :luk_total, :integer, default: 100
    field :luk_min, :integer, default: 0
    field :luk_max, :integer, default: 100

    field :hp_total, :integer, default: 1000
    field :hp_min, :integer, default: 0
    field :hp_max, :integer, default: 1000

    field :current_hp_total, :integer, default: 0
    field :current_hp_min, :integer, default: 500
    field :current_hp_max, :integer, default: 0

    field :hp_regen_total, :integer, default: 100
    field :hp_regen_min, :integer, default: 0
    field :hp_regen_max, :integer, default: 100

    field :unknown7_total, :integer, default: 100
    field :unknown7_min, :integer, default: 0
    field :unknown7_max, :integer, default: 100

    field :spirit_total, :integer, default: 100
    field :spirit_min, :integer, default: 100
    field :spirit_max, :integer, default: 100

    field :unknown9_total, :integer, default: 100
    field :unknown9_min, :integer, default: 0
    field :unknown9_max, :integer, default: 100

    field :unknown10_total, :integer, default: 100
    field :unknown10_min, :integer, default: 0
    field :unknown10_max, :integer, default: 100

    field :stamina_total, :integer, default: 120
    field :stamina_min, :integer, default: 120
    field :stamina_max, :integer, default: 120

    field :unknown12_total, :integer, default: 100
    field :unknown12_min, :integer, default: 0
    field :unknown12_max, :integer, default: 100

    field :unknown13_total, :integer, default: 100
    field :unknown13_min, :integer, default: 0
    field :unknown13_max, :integer, default: 100

    field :attk_speed_total, :integer, default: 120
    field :attk_speed_min, :integer, default: 1000
    field :attk_speed_max, :integer, default: 130

    field :mov_speed_total, :integer, default: 110
    field :mov_speed_min, :integer, default: 100
    field :mov_speed_max, :integer, default: 150

    field :accuracy_total, :integer, default: 100
    field :accuracy_min, :integer, default: 0
    field :accuracy_max, :integer, default: 100

    field :evasion_total, :integer, default: 100
    field :evasion_min, :integer, default: 0
    field :evasion_max, :integer, default: 100

    field :crit_rate_total, :integer, default: 100
    field :crit_rate_min, :integer, default: 0
    field :crit_rate_max, :integer, default: 100

    field :crit_dmg_total, :integer, default: 100
    field :crit_dmg_min, :integer, default: 0
    field :crit_dmg_max, :integer, default: 100

    field :crit_evasion_total, :integer, default: 100
    field :crit_evasion_min, :integer, default: 0
    field :crit_evasion_max, :integer, default: 100

    field :def_total, :integer, default: 100
    field :def_min, :integer, default: 0
    field :def_max, :integer, default: 100

    field :guard_total, :integer, default: 100
    field :guard_min, :integer, default: 0
    field :guard_max, :integer, default: 100

    field :jump_height_total, :integer, default: 110
    field :jump_height_min, :integer, default: 100
    field :jump_height_max, :integer, default: 130

    field :phys_attk_total, :integer, default: 100
    field :phys_attk_min, :integer, default: 0
    field :phys_attk_max, :integer, default: 100

    field :magic_attk_total, :integer, default: 100
    field :magic_attk_min, :integer, default: 0
    field :magic_attk_max, :integer, default: 100

    field :phys_res_total, :integer, default: 100
    field :phys_res_min, :integer, default: 0
    field :phys_res_max, :integer, default: 100

    field :magic_res_total, :integer, default: 100
    field :magic_res_min, :integer, default: 0
    field :magic_res_max, :integer, default: 100

    field :min_attk_total, :integer, default: 100
    field :min_attk_min, :integer, default: 0
    field :min_attk_max, :integer, default: 100

    field :max_attk_total, :integer, default: 100
    field :max_attk_min, :integer, default: 0
    field :max_attk_max, :integer, default: 100

    field :unknown30_total, :integer, default: 100
    field :unknown30_min, :integer, default: 0
    field :unknown30_max, :integer, default: 100

    field :unknown31_total, :integer, default: 100
    field :unknown31_min, :integer, default: 0
    field :unknown31_max, :integer, default: 100

    field :pierce_total, :integer, default: 100
    field :pierce_min, :integer, default: 0
    field :pierce_max, :integer, default: 100

    field :mount_speed_total, :integer, default: 100
    field :mount_speed_min, :integer, default: 100
    field :mount_speed_max, :integer, default: 100

    field :bonus_attk_total, :integer, default: 100
    field :bonus_attk_min, :integer, default: 0
    field :bonus_attk_max, :integer, default: 100

    field :unknown35_total, :integer, default: 100
    field :unknown35_min, :integer, default: 0
    field :unknown35_max, :integer, default: 100
  end

  @doc false
  def changeset(character_stats, attrs) do
    character_stats
    |> cast(attrs, fields())
    |> validate_required(fields())
  end

  def fields() do
    Enum.reduce(@stats, [], fn s, list ->
      list ++ [:"#{s}_total", :"#{s}_min", :"#{s}_max"]
    end)
  end
end
