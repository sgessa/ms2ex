defmodule Ms2ex.Schema.CharacterStats do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ms2ex.{Enums, Schema}

  schema "character_stats" do
    belongs_to :character, Schema.Character

    field :pet_bonus_atk_min, :integer, default: 0
    field :pet_bonus_atk_cur, :integer, default: 0
    field :pet_bonus_atk_max, :integer, default: 0

    field :critical_damage_min, :integer, default: 250
    field :critical_damage_cur, :integer, default: 250
    field :critical_damage_max, :integer, default: 250

    field :max_weapon_atk_min, :integer, default: 0
    field :max_weapon_atk_cur, :integer, default: 0
    field :max_weapon_atk_max, :integer, default: 0

    field :hp_regen_min, :integer, default: 10
    field :hp_regen_cur, :integer, default: 10
    field :hp_regen_max, :integer, default: 10

    field :physical_res_min, :integer, default: 5
    field :physical_res_cur, :integer, default: 5
    field :physical_res_max, :integer, default: 5

    field :spirit_min, :integer, default: 100
    field :spirit_cur, :integer, default: 100
    field :spirit_max, :integer, default: 100

    field :stamina_min, :integer, default: 120
    field :stamina_cur, :integer, default: 120
    field :stamina_max, :integer, default: 120

    field :min_weapon_atk_min, :integer, default: 0
    field :min_weapon_atk_cur, :integer, default: 0
    field :min_weapon_atk_max, :integer, default: 0

    field :defense_min, :integer, default: 16
    field :defense_cur, :integer, default: 16
    field :defense_max, :integer, default: 16

    field :perfect_guard_min, :integer, default: 0
    field :perfect_guard_cur, :integer, default: 0
    field :perfect_guard_max, :integer, default: 0

    field :magical_atk_min, :integer, default: 2
    field :magical_atk_cur, :integer, default: 2
    field :magical_atk_max, :integer, default: 2

    field :health_min, :integer, default: 500
    field :health_cur, :integer, default: 500
    field :health_max, :integer, default: 500

    field :sp_regen_interval_min, :integer, default: 200
    field :sp_regen_interval_cur, :integer, default: 200
    field :sp_regen_interval_max, :integer, default: 200

    field :critical_evasion_min, :integer, default: 50
    field :critical_evasion_cur, :integer, default: 50
    field :critical_evasion_max, :integer, default: 50

    field :physical_atk_min, :integer, default: 10
    field :physical_atk_cur, :integer, default: 10
    field :physical_atk_max, :integer, default: 10

    field :attack_speed_min, :integer, default: 100
    field :attack_speed_cur, :integer, default: 100
    field :attack_speed_max, :integer, default: 100

    field :strength_min, :integer, default: 10
    field :strength_cur, :integer, default: 10
    field :strength_max, :integer, default: 10

    field :piercing_min, :integer, default: 0
    field :piercing_cur, :integer, default: 0
    field :piercing_max, :integer, default: 0

    field :evasion_min, :integer, default: 70
    field :evasion_cur, :integer, default: 70
    field :evasion_max, :integer, default: 70

    field :damage_min, :integer, default: 0
    field :damage_cur, :integer, default: 0
    field :damage_max, :integer, default: 0

    field :bonus_atk_min, :integer, default: 0
    field :bonus_atk_cur, :integer, default: 0
    field :bonus_atk_max, :integer, default: 0

    field :sp_regen_min, :integer, default: 1
    field :sp_regen_cur, :integer, default: 1
    field :sp_regen_max, :integer, default: 1

    field :stamina_regen_min, :integer, default: 10
    field :stamina_regen_cur, :integer, default: 10
    field :stamina_regen_max, :integer, default: 10

    field :movement_speed_min, :integer, default: 100
    field :movement_speed_cur, :integer, default: 100
    field :movement_speed_max, :integer, default: 100

    field :intelligence_min, :integer, default: 10
    field :intelligence_cur, :integer, default: 10
    field :intelligence_max, :integer, default: 10

    field :hp_regen_interval_min, :integer, default: 3000
    field :hp_regen_interval_cur, :integer, default: 3000
    field :hp_regen_interval_max, :integer, default: 3000

    field :jump_height_min, :integer, default: 100
    field :jump_height_cur, :integer, default: 100
    field :jump_height_max, :integer, default: 100

    field :accuracy_min, :integer, default: 82
    field :accuracy_cur, :integer, default: 82
    field :accuracy_max, :integer, default: 82

    field :dexterity_min, :integer, default: 10
    field :dexterity_cur, :integer, default: 10
    field :dexterity_max, :integer, default: 10

    field :unknown_min, :integer, default: 0
    field :unknown_cur, :integer, default: 0
    field :unknown_max, :integer, default: 0

    field :critical_rate_min, :integer, default: 10
    field :critical_rate_cur, :integer, default: 10
    field :critical_rate_max, :integer, default: 10

    field :magical_res_min, :integer, default: 4
    field :magical_res_cur, :integer, default: 4
    field :magical_res_max, :integer, default: 4

    field :stamina_regen_interval_min, :integer, default: 500
    field :stamina_regen_interval_cur, :integer, default: 500
    field :stamina_regen_interval_max, :integer, default: 500

    field :mount_speed_min, :integer, default: 100
    field :mount_speed_cur, :integer, default: 100
    field :mount_speed_max, :integer, default: 100

    field :luck_min, :integer, default: 10
    field :luck_cur, :integer, default: 10
    field :luck_max, :integer, default: 10
  end

  @doc false
  def changeset(character_stats, attrs) do
    character_stats
    |> cast(attrs, fields())
    |> validate_required(fields())
  end

  def fields() do
    Enums.BasicStatType.all()
    |> Enum.map(&[:"#{&1}_min", :"#{&1}_cur", :"#{&1}_max"])
    |> List.flatten()
  end
end
