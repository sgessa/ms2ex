defmodule Ms2ex.Items.StatAttribute do
  import EctoEnum

  defenum(Type,
    str: 0,
    dex: 1,
    int: 2,
    luk: 3,
    hp: 4,
    hp_regen: 5,
    hp_regen_interval: 6,
    sp: 7,
    sp_regen: 8,
    sp_regen_interval: 9,
    stamina: 10,
    stamina_regen: 11,
    stamina_regen_intval: 12,
    attk_speed: 13,
    move_speed: 14,
    accuracy: 15,
    evasion: 16,
    crit_rate: 17,
    crit_damage: 18,
    crit_evasion: 19,
    defense: 20,
    perfect_guard: 21,
    jump_height: 22,
    physical_attk: 23,
    magic_attk: 24,
    physical_res: 25,
    magic_res: 26,
    min_weapon_attk: 27,
    max_weapon_attk: 28,
    min_damage: 29,
    max_damage: 30,
    pierce: 31,
    mount_movement_speed: 32,
    bonus_attk: 33,
    pet_bonus_attk: 34,
    exp_bonus: 11001,
    meso_bonus: 11002,
    swim_speed: 11003,
    dash_distance: 11004,
    tonic_drop_rate: 11005,
    gear_drop_rate: 11006,
    total_damage: 11007,
    critical_damage: 11008,
    damage: 11009,
    leader_damage: 11010,
    elite_damage: 11011,
    # This is actually used in conjunction with "sgi_target" in the XMLs.,
    # It's not boss damage: it's for a specified monster type.,
    # Currently ignoring it and just using it as boss damage: as nothing in the data uses it for non-boss mobs,
    boss_damage: 11012,
    hp_on_kill: 11013,
    spirit_on_kill: 11014,
    stamina_on_kill: 11015,
    heal: 11016,
    ally_recovery: 11017,
    ice_damage: 11018,
    fire_damage: 11019,
    dark_damage: 11020,
    holy_damage: 11021,
    poison_damage: 11022,
    electric_damage: 11023,
    melee_damage: 11024,
    ranged_damage: 11025,
    physical_piercing: 11026,
    magical_piercing: 11027,
    ice_damage_reduce: 11028,
    fire_damage_reduce: 11029,
    dark_damage_reduce: 11030,
    holy_damage_reduce: 11031,
    poison_damage_reduce: 11032,
    electric_damage_reduce: 11033,
    stun_reduce: 11034,
    cooldown_reduce: 11035,
    debuff_duration_reduce: 11036,
    melee_damage_reduce: 11037,
    ranged_damage_reduce: 11038,
    knockback_reduce: 11039,
    # melee chance to stun,
    melee_stun: 11040,
    # melee chance to stun,
    ranged_stun: 11041,
    # chance of knockback after meele att,
    melee_knockback: 11042,
    # chance of knockback after ranged att,
    ranged_knockback: 11043,
    # ranged chance to immob,
    melee_immob: 11044,
    # ranged chance to immob,
    ranged_immob: 11045,
    # melee chance to do aoe damage,
    melee_aoe_damage: 11046,
    # ranged chance to do aoe damage,
    ranged_aoe_damage: 11047,
    drop_rate: 11048,
    quest_exp: 11049,
    quest_meso: 11050,
    # needs better name,
    InvokeEffect1: 11051,
    # needs better name,
    InvokeEffect2: 11052,
    # needs better name,
    InvokeEffect3: 11053,
    PvPDamage: 11054,
    PvPDefense: 11055,
    GuildExp: 11056,
    GuildCoin: 11057,
    # mc-kay experience orb value bonus,
    McKayXpOrb: 11058,
    FishingExp: 11059,
    ArcadeExp: 11060,
    PerformanceExp: 11061,
    # assistant mood improvement rate,
    AssistantMood: 11062,
    AssistantDiscount: 11063,
    BlackMarketReduce: 11064,
    EnchantCatalystDiscount: 11065,
    MeretReviveFee: 11066,
    MiningBonus: 11067,
    RanchingBonus: 11068,
    SmithingExp: 11069,
    HandicraftMastery: 11070,
    ForagingBonus: 11071,
    FarmingBonus: 11072,
    AlchemyMastery: 11073,
    CookingMastery: 11074,
    ForagingExp: 11075,
    CraftingExp: 11076,
    # level 1 skill,
    TECH: 11077,
    # 2nd level 1 skill,
    TECH_2: 11078,
    # lv 10 skill,
    TECH_10: 11079,
    # lv 13 skill,
    TECH_13: 11080,
    # lv 16 skill,
    TECH_16: 11081,
    # lv 19 skill,
    TECH_19: 11082,
    # lv 22 skill,
    TECH_22: 11083,
    # lv 25 skill,
    TECH_25: 11084,
    # lv 28 skill,
    TECH_28: 11085,
    # lv 31 skill,
    TECH_31: 11086,
    # lv 34 skill,
    TECH_34: 11087,
    # lv 37 skill,
    TECH_37: 11088,
    # lv 40 skill,
    TECH_40: 11089,
    # lv 43 skill,
    TECH_43: 11090,
    OXQuizExp: 11091,
    TrapMasterExp: 11092,
    SoleSurvivorExp: 11093,
    CrazyRunnerExp: 11094,
    LudiEscapeExp: 11095,
    SpringBeachExp: 11096,
    DanceDanceExp: 11097,
    OXMovementSpeed: 11098,
    TrapMasterMovementSpeed: 11099,
    SoleSurvivorMovementSpeed: 11100,
    CrazyRunnerMovementSpeed: 11101,
    LudiEscapeMovementSpeed: 11102,
    SpringBeachMovementSpeed: 11103,
    DanceDanceStopMovementSpeed: 11104,
    GenerateSpiritOrbs: 11105,
    GenerateStaminaOrbs: 11106,
    ValorTokens: 11107,
    PvPExp: 11108,
    DarkDescentDamageBonus: 11109,
    DarkDescentDamageReduce: 11110,
    DarkDescentEvasion: 11111,
    DoubleFishingMastery: 11112,
    DoublePerformanceMastery: 11113,
    ExploredAreasMovementSpeed: 11114,
    AirMountAscentSpeed: 11115,
    EnemyDefenseDecreaseOnHit: 11117,
    EnemyAttackDecreaseOnHit: 11118,
    # Increases damage if there is an enemy within 5m,
    IncreaseTotalDamageIf1NearbyEnemy: 11119,
    # Increases damage if there is at least 3 enemies within 5m,
    IncreaseTotalDamageIf3NearbyEnemies: 11120,
    # Increase damage if you have 80 or more spirit,
    IncreaseTotalDamageIf80Spirit: 11121,
    IncreaseTotalDamageIfFullStamina: 11122,
    # Increase damage if you have a herb-like effect active,
    IncreaseTotalDamageIfHerbEffectActive: 11123,
    IncreaseTotalDamageToWorldBoss: 11124,
    Effect95000026: 11125,
    Effect95000027: 11126,
    Effect95000028: 11127,
    Effect95000029: 11128,
    StaminaRecoverySpeed: 11129,
    MaxWeaponAttack: 11130,
    DoubleMiningProduction: 11131,
    DoubleRanchingProduction: 11132,
    DoubleForagingProduction: 11133,
    DoubleFarmingProduction: 11134,
    DoubleSmithingProduction: 11135,
    DoubleHandicraftProduction: 11136,
    DoubleAlchemyProduction: 11137,
    DoubleCookingProduction: 11138,
    DoubleMiningMastery: 11139,
    DoubleRanchingMastery: 11140,
    DoubleForagingMastery: 11141,
    DoubleFarmingMastery: 11142,
    DoubleSmithingMastery: 11143,
    DoubleHandicraftMastery: 11144,
    DoubleAlchemyMastery: 11145,
    DoubleCookingMastery: 11146,
    ChaosRaidWeaponAttack: 11147,
    ChaosRaidAttackSpeed: 11148,
    ChaosRaidAccuracy: 11149,
    ChaosRaidHealth: 11150,
    StaminaAndSpiritFromOrbs: 11151,
    WorldBossExp: 11152,
    WorldBossDropRate: 11153,
    WorldBossDamageReduce: 11154,
    Effect9500016: 11155,
    PetCaptureRewards: 11156,
    MiningEfficency: 11157,
    RanchingEfficiency: 11158,
    ForagingEfficiency: 11159,
    FarmingEfficiency: 11160,
    ShanghaiCrazyRunnersExp: 11161,
    ShanghaiCrazyRunnersMovementSpeed: 11162,
    HealthBasedDamageReduce: 11163
  )

  def from_name(name) do
    id = Type.__enum_map__()[name]

    cond do
      id > 11000 -> id - 11000
      true -> id
    end
  end
end
