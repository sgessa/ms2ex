defmodule Ms2ex.Metadata.Items.StatAttribute do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :str, 0
  field :dex, 1
  field :int, 2
  field :luk, 3
  field :hp, 4
  field :hp_regen, 5
  field :hp_regen_interval, 6
  field :sp, 7
  field :sp_regen, 8
  field :sp_regen_interval, 9
  field :stamina, 10
  field :stamina_regen, 11
  field :stamina_regen_intval, 12
  field :attk_speed, 13
  field :move_speed, 14
  field :accuracy, 15
  field :evasion, 16
  field :crit_rate, 17
  field :crit_damage, 18
  field :crit_evasion, 19
  field :defense, 20
  field :perfect_guard, 21
  field :jump_height, 22
  field :phys_attk, 23
  field :mag_attk, 24
  field :phys_res, 25
  field :mag_res, 26
  field :min_weapon_attk, 27
  field :max_weapon_attk, 28
  field :min_damage, 29
  field :max_damage, 30
  field :pierce, 31
  field :mount_movement_speed, 32
  field :bonus_attk, 33
  field :pet_bonus_attk, 34
  field :exp_bonus, 11001
  field :meso_bonus, 11002
  field :swim_speed, 11003
  field :dash_distance, 11004
  field :tonic_drop_rate, 11005
  field :gear_drop_rate, 11006
  field :total_damage, 11007
  field :critical_damage, 11008
  field :damage, 11009
  field :leader_damage, 11010
  field :elite_damage, 11011

  # This is actually used in conjunction with "sgi_target" in the XMLs.
  # It's not boss damage, it's for a specified monster type.
  # Currently ignoring it and just using it as boss damage, as nothing in the data uses it for non-boss mobs
  field :boss_damage, 11012
  field :hp_on_kill, 11013
  field :spirit_on_kill, 11014
  field :stamina_on_kill, 11015
  field :heal, 11016
  field :ally_recovery, 11017
  field :ice_damage, 11018
  field :fire_damage, 11019
  field :dark_damage, 11020
  field :holy_damage, 11021
  field :poison_damage, 11022
  field :electric_damage, 11023
  field :melee_damage, 11024
  field :ranged_damage, 11025
  field :physical_piercing, 11026
  field :magical_piercing, 11027
  field :ice_damage_reduce, 11028
  field :fire_damage_reduce, 11029
  field :dark_damage_reduce, 11030
  field :holy_damage_reduce, 11031
  field :poison_damage_reduce, 11032
  field :electric_damage_reduce, 11033
  field :stun_reduce, 11034
  field :cooldown_reduce, 11035
  field :debuff_duration_reduce, 11036
  field :melee_damage_reduce, 11037
  field :ranged_damage_reduce, 11038
  field :knockback_reduce, 11039
  # melee chance to stun
  field :melee_stun, 11040
  # melee chance to stun
  field :ranged_stun, 11041
  # chance of knockback after meele att
  field :melee_knockback, 11042
  # chance of knockback after ranged att
  field :ranged_knockback, 11043
  # ranged chance to immob
  field :melee_immob, 11044
  # ranged chance to immob
  field :ranged_immob, 11045
  # melee chance to do aoe damage
  field :melee_aoe_damage, 11046
  # ranged chance to do aoe damage
  field :ranged_aoe_damage, 11047
  field :drop_rate, 11048
  field :quest_exp, 11049
  field :quest_meso, 11050
  # field :needs better name
  field :InvokeEffect1, 11051
  # field :needs better name
  field :InvokeEffect2, 11052
  # field :needs better name
  field :InvokeEffect3, 11053
  field :PvPDamage, 11054
  field :PvPDefense, 11055
  field :GuildExp, 11056
  field :GuildCoin, 11057
  # mc-kay experience orb value bonus
  field :McKayXpOrb, 11058
  field :FishingExp, 11059
  field :ArcadeExp, 11060
  field :PerformanceExp, 11061
  # assistant mood improvement rate
  field :AssistantMood, 11062
  field :AssistantDiscount, 11063
  field :BlackMarketReduce, 11064
  field :EnchantCatalystDiscount, 11065
  field :MeretReviveFee, 11066
  field :MiningBonus, 11067
  field :RanchingBonus, 11068
  field :SmithingExp, 11069
  field :HandicraftMastery, 11070
  field :ForagingBonus, 11071
  field :FarmingBonus, 11072
  field :AlchemyMastery, 11073
  field :CookingMastery, 11074
  field :ForagingExp, 11075
  field :CraftingExp, 11076

  # level 1 skill
  field :TECH, 11077
  # 2nd level 1 skill
  field :TECH_2, 11078
  # lv 10 skill
  field :TECH_10, 11079
  # lv 13 skill
  field :TECH_13, 11080
  # field :lv 16 skill
  field :TECH_16, 11081
  # field :lv 19 skill
  field :TECH_19, 11082
  # field :lv 22 skill
  field :TECH_22, 11083
  # field :lv 25 skill
  field :TECH_25, 11084
  # field :lv 28 skill
  field :TECH_28, 11085
  # field :lv 31 skill
  field :TECH_31, 11086
  # field :lv 34 skill
  field :TECH_34, 11087
  # field :lv 37 skill
  field :TECH_37, 11088
  # field :lv 40 skill
  field :TECH_40, 11089
  # field :lv 43 skill
  field :TECH_43, 11090

  field :OXQuizExp, 11091
  field :TrapMasterExp, 11092
  field :SoleSurvivorExp, 11093
  field :CrazyRunnerExp, 11094
  field :LudiEscapeExp, 11095
  field :SpringBeachExp, 11096
  field :DanceDanceExp, 11097
  field :OXMovementSpeed, 11098
  field :TrapMasterMovementSpeed, 11099
  field :SoleSurvivorMovementSpeed, 11100
  field :CrazyRunnerMovementSpeed, 11101
  field :LudiEscapeMovementSpeed, 11102
  field :SpringBeachMovementSpeed, 11103
  field :DanceDanceStopMovementSpeed, 11104
  field :GenerateSpiritOrbs, 11105
  field :GenerateStaminaOrbs, 11106
  field :ValorTokens, 11107
  field :PvPExp, 11108
  field :DarkDescentDamageBonus, 11109
  field :DarkDescentDamageReduce, 11110
  field :DarkDescentEvasion, 11111
  field :DoubleFishingMastery, 11112
  field :DoublePerformanceMastery, 11113
  field :ExploredAreasMovementSpeed, 11114
  field :AirMountAscentSpeed, 11115
  field :EnemyDefenseDecreaseOnHit, 11117
  field :EnemyAttackDecreaseOnHit, 11118
  # field :Increases damage if there is an enemy within 5m
  field :IncreaseTotalDamageIf1NearbyEnemy, 11119
  # field :Increases damage if there is at least 3 enemies within 5m
  field :IncreaseTotalDamageIf3NearbyEnemies, 11120
  # field :Increase damage if you have 80 or more spirit
  field :IncreaseTotalDamageIf80Spirit, 11121
  field :IncreaseTotalDamageIfFullStamina, 11122
  # field :Increase damage if you have a herb-like effect active
  field :IncreaseTotalDamageIfHerbEffectActive, 11123
  field :IncreaseTotalDamageToWorldBoss, 11124
  field :Effect95000026, 11125
  field :Effect95000027, 11126
  field :Effect95000028, 11127
  field :Effect95000029, 11128
  field :StaminaRecoverySpeed, 11129
  field :MaxWeaponAttack, 11130
  field :DoubleMiningProduction, 11131
  field :DoubleRanchingProduction, 11132
  field :DoubleForagingProduction, 11133
  field :DoubleFarmingProduction, 11134
  field :DoubleSmithingProduction, 11135
  field :DoubleHandicraftProduction, 11136
  field :DoubleAlchemyProduction, 11137
  field :DoubleCookingProduction, 11138
  field :DoubleMiningMastery, 11139
  field :DoubleRanchingMastery, 11140
  field :DoubleForagingMastery, 11141
  field :DoubleFarmingMastery, 11142
  field :DoubleSmithingMastery, 11143
  field :DoubleHandicraftMastery, 11144
  field :DoubleAlchemyMastery, 11145
  field :DoubleCookingMastery, 11146
  field :ChaosRaidWeaponAttack, 11147
  field :ChaosRaidAttackSpeed, 11148
  field :ChaosRaidAccuracy, 11149
  field :ChaosRaidHealth, 11150
  field :StaminaAndSpiritFromOrbs, 11151
  field :WorldBossExp, 11152
  field :WorldBossDropRate, 11153
  field :WorldBossDamageReduce, 11154
  field :Effect9500016, 11155
  field :PetCaptureRewards, 11156
  field :MiningEfficency, 11157
  field :RanchingEfficiency, 11158
  field :ForagingEfficiency, 11159
  field :FarmingEfficiency, 11160
  field :ShanghaiCrazyRunnersExp, 11161
  field :ShanghaiCrazyRunnersMovementSpeed, 11162
  field :HealthBasedDamageReduce, 11163
end
