defmodule Ms2ex.Schema.CharacterStats do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ms2ex.{Enums, Schema}

  schema "character_stats" do
    belongs_to :character, Schema.Character

    field :str_min, :integer, default: 10
    field :str_cur, :integer, default: 10
    field :str_max, :integer, default: 10

    field :dex_min, :integer, default: 10
    field :dex_cur, :integer, default: 10
    field :dex_max, :integer, default: 10

    field :int_min, :integer, default: 10
    field :int_cur, :integer, default: 10
    field :int_max, :integer, default: 10

    field :luk_min, :integer, default: 10
    field :luk_cur, :integer, default: 10
    field :luk_max, :integer, default: 10

    field :hp_min, :integer, default: 500
    field :hp_cur, :integer, default: 500
    field :hp_max, :integer, default: 500

    field :hp_regen_min, :integer, default: 10
    field :hp_regen_cur, :integer, default: 10
    field :hp_regen_max, :integer, default: 10

    field :hp_regen_time_min, :integer, default: 3000
    field :hp_regen_time_max, :integer, default: 3000
    field :hp_regen_time_cur, :integer, default: 3000

    field :sp_min, :integer, default: 100
    field :sp_cur, :integer, default: 100
    field :sp_max, :integer, default: 100

    field :sp_regen_min, :integer, default: 1
    field :sp_regen_cur, :integer, default: 1
    field :sp_regen_max, :integer, default: 1

    field :sp_regen_time_min, :integer, default: 200
    field :sp_regen_time_cur, :integer, default: 200
    field :sp_regen_time_max, :integer, default: 200

    field :sta_min, :integer, default: 120
    field :sta_cur, :integer, default: 120
    field :sta_max, :integer, default: 120

    field :sta_regen_min, :integer, default: 10
    field :sta_regen_cur, :integer, default: 10
    field :sta_regen_max, :integer, default: 10

    field :sta_regen_time_min, :integer, default: 500
    field :sta_regen_time_cur, :integer, default: 500
    field :sta_regen_time_max, :integer, default: 500

    field :attk_speed_min, :integer, default: 100
    field :attk_speed_cur, :integer, default: 100
    field :attk_speed_max, :integer, default: 100

    field :mov_speed_min, :integer, default: 100
    field :mov_speed_cur, :integer, default: 100
    field :mov_speed_max, :integer, default: 100

    field :accuracy_min, :integer, default: 82
    field :accuracy_cur, :integer, default: 82
    field :accuracy_max, :integer, default: 82

    field :evasion_min, :integer, default: 70
    field :evasion_cur, :integer, default: 70
    field :evasion_max, :integer, default: 70

    field :crit_rate_min, :integer, default: 10
    field :crit_rate_cur, :integer, default: 10
    field :crit_rate_max, :integer, default: 10

    field :crit_dmg_min, :integer, default: 250
    field :crit_dmg_cur, :integer, default: 250
    field :crit_dmg_max, :integer, default: 250

    field :crit_evasion_min, :integer, default: 50
    field :crit_evasion_cur, :integer, default: 50
    field :crit_evasion_max, :integer, default: 50

    field :def_min, :integer, default: 16
    field :def_cur, :integer, default: 16
    field :def_max, :integer, default: 16

    field :guard_min, :integer, default: 0
    field :guard_cur, :integer, default: 0
    field :guard_max, :integer, default: 0

    field :jump_height_min, :integer, default: 100
    field :jump_height_cur, :integer, default: 100
    field :jump_height_max, :integer, default: 100

    field :phys_attk_min, :integer, default: 10
    field :phys_attk_cur, :integer, default: 10
    field :phys_attk_max, :integer, default: 10

    field :magic_attk_min, :integer, default: 2
    field :magic_attk_cur, :integer, default: 2
    field :magic_attk_max, :integer, default: 2

    field :phys_res_min, :integer, default: 5
    field :phys_res_cur, :integer, default: 5
    field :phys_res_max, :integer, default: 5

    field :magic_res_min, :integer, default: 4
    field :magic_res_cur, :integer, default: 4
    field :magic_res_max, :integer, default: 4

    field :min_attk_min, :integer, default: 0
    field :min_attk_cur, :integer, default: 0
    field :min_attk_max, :integer, default: 0

    field :max_attk_min, :integer, default: 0
    field :max_attk_cur, :integer, default: 0
    field :max_attk_max, :integer, default: 0

    field :min_dmg_min, :integer, default: 0
    field :min_dmg_cur, :integer, default: 0
    field :min_dmg_max, :integer, default: 0

    field :max_dmg_min, :integer, default: 0
    field :max_dmg_cur, :integer, default: 0
    field :max_dmg_max, :integer, default: 0

    field :pierce_min, :integer, default: 0
    field :pierce_cur, :integer, default: 0
    field :pierce_max, :integer, default: 0

    field :mount_speed_min, :integer, default: 100
    field :mount_speed_cur, :integer, default: 100
    field :mount_speed_max, :integer, default: 100

    field :bonus_attk_min, :integer, default: 0
    field :bonus_attk_cur, :integer, default: 0
    field :bonus_attk_max, :integer, default: 0

    field :pet_bonus_attk_min, :integer, default: 0
    field :pet_bonus_attk_cur, :integer, default: 0
    field :pet_bonus_attk_max, :integer, default: 0
  end

  @doc false
  def changeset(character_stats, attrs) do
    character_stats
    |> cast(attrs, fields())
    |> validate_required(fields())
  end

  def fields() do
    Enums.StatId.keys()
    |> Enum.map(&[:"#{&1}_min", :"#{&1}_cur", :"#{&1}_max"])
    |> List.flatten()
  end

  # def ordered_fields() do
  #   Enums.StatId.values()
  #   |> Enum.sort()
  #   |> Enum.map(fn stat_value ->
  #     stat_name = Enums.StatId.get_key(stat_value)
  #     [:"#{stat_name}_min", :"#{stat_name}_cur", :"#{stat_name}_max"]
  #   end)
  #   |> List.flatten()
  # end
end
