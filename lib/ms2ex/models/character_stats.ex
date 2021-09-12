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
    :hp_regen_time,
    :spirit,
    :sp_regen,
    :sp_regen_time,
    :stamina,
    :stamina_regen,
    :stamina_regen_time,
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
    :min_dmg,
    :max_dmg,
    :pierce,
    :mount_speed,
    :bonus_attk,
    :pet_bonus_attk
  ]

  schema "character_stats" do
    belongs_to :character, Ms2ex.Character

    field :str_min, :integer, default: 10
    field :str_max, :integer, default: 10
    field :str_cur, :integer, default: 10

    field :dex_min, :integer, default: 10
    field :dex_max, :integer, default: 10
    field :dex_cur, :integer, default: 10

    field :int_min, :integer, default: 10
    field :int_max, :integer, default: 10
    field :int_cur, :integer, default: 10

    field :luk_min, :integer, default: 10
    field :luk_max, :integer, default: 10
    field :luk_cur, :integer, default: 10

    field :hp_min, :integer, default: 500
    field :hp_max, :integer, default: 500
    field :hp_cur, :integer, default: 500

    field :current_hp_min, :integer, default: 500
    field :current_hp_max, :integer, default: 0
    field :current_hp_cur, :integer, default: 0

    field :hp_regen_min, :integer, default: 10
    field :hp_regen_max, :integer, default: 10
    field :hp_regen_cur, :integer, default: 10

    field :hp_regen_time_min, :integer, default: 3000
    field :hp_regen_time_max, :integer, default: 3000
    field :hp_regen_time_cur, :integer, default: 3000

    field :spirit_min, :integer, default: 100
    field :spirit_max, :integer, default: 100
    field :spirit_cur, :integer, default: 100

    field :sp_regen_min, :integer, default: 1
    field :sp_regen_max, :integer, default: 1
    field :sp_regen_cur, :integer, default: 1

    field :sp_regen_time_min, :integer, default: 200
    field :sp_regen_time_max, :integer, default: 200
    field :sp_regen_time_cur, :integer, default: 200

    field :stamina_min, :integer, default: 120
    field :stamina_max, :integer, default: 120
    field :stamina_cur, :integer, default: 120

    field :stamina_regen_min, :integer, default: 10
    field :stamina_regen_max, :integer, default: 10
    field :stamina_regen_cur, :integer, default: 10

    field :stamina_regen_time_min, :integer, default: 500
    field :stamina_regen_time_max, :integer, default: 500
    field :stamina_regen_time_cur, :integer, default: 500

    field :attk_speed_min, :integer, default: 100
    field :attk_speed_max, :integer, default: 100
    field :attk_speed_cur, :integer, default: 100

    field :mov_speed_min, :integer, default: 100
    field :mov_speed_max, :integer, default: 100
    field :mov_speed_cur, :integer, default: 100

    field :accuracy_min, :integer, default: 82
    field :accuracy_max, :integer, default: 82
    field :accuracy_cur, :integer, default: 82

    field :evasion_min, :integer, default: 70
    field :evasion_max, :integer, default: 70
    field :evasion_cur, :integer, default: 70

    field :crit_rate_min, :integer, default: 10
    field :crit_rate_max, :integer, default: 10
    field :crit_rate_cur, :integer, default: 10

    field :crit_dmg_min, :integer, default: 250
    field :crit_dmg_max, :integer, default: 250
    field :crit_dmg_cur, :integer, default: 250

    field :crit_evasion_min, :integer, default: 50
    field :crit_evasion_max, :integer, default: 50
    field :crit_evasion_cur, :integer, default: 50

    field :def_min, :integer, default: 16
    field :def_max, :integer, default: 16
    field :def_cur, :integer, default: 16

    field :guard_min, :integer, default: 0
    field :guard_max, :integer, default: 0
    field :guard_cur, :integer, default: 0

    field :jump_height_min, :integer, default: 100
    field :jump_height_max, :integer, default: 100
    field :jump_height_cur, :integer, default: 100

    field :phys_attk_min, :integer, default: 10
    field :phys_attk_max, :integer, default: 10
    field :phys_attk_cur, :integer, default: 10

    field :magic_attk_min, :integer, default: 2
    field :magic_attk_max, :integer, default: 2
    field :magic_attk_cur, :integer, default: 2

    field :phys_res_min, :integer, default: 5
    field :phys_res_max, :integer, default: 5
    field :phys_res_cur, :integer, default: 5

    field :magic_res_min, :integer, default: 4
    field :magic_res_max, :integer, default: 4
    field :magic_res_cur, :integer, default: 4

    field :min_attk_min, :integer, default: 0
    field :min_attk_max, :integer, default: 0
    field :min_attk_cur, :integer, default: 0

    field :max_attk_min, :integer, default: 0
    field :max_attk_max, :integer, default: 0
    field :max_attk_cur, :integer, default: 0

    field :min_dmg_min, :integer, default: 0
    field :min_dmg_max, :integer, default: 0
    field :min_dmg_cur, :integer, default: 0

    field :max_dmg_min, :integer, default: 0
    field :max_dmg_max, :integer, default: 0
    field :max_dmg_cur, :integer, default: 0

    field :pierce_min, :integer, default: 0
    field :pierce_max, :integer, default: 0
    field :pierce_cur, :integer, default: 0

    field :mount_speed_cur, :integer, default: 100
    field :mount_speed_min, :integer, default: 100
    field :mount_speed_max, :integer, default: 100

    field :bonus_attk_cur, :integer, default: 0
    field :bonus_attk_min, :integer, default: 0
    field :bonus_attk_max, :integer, default: 0

    field :pet_bonus_attk_cur, :integer, default: 0
    field :pet_bonus_attk_min, :integer, default: 0
    field :pet_bonus_attk_max, :integer, default: 0
  end

  @doc false
  def changeset(character_stats, attrs) do
    character_stats
    |> cast(attrs, fields())
    |> validate_required(fields())
  end

  def fields() do
    Enum.reduce(@stats, [], fn s, list ->
      list ++ [:"#{s}_cur", :"#{s}_min", :"#{s}_max"]
    end)
  end
end
