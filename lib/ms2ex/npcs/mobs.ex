defmodule Ms2ex.Mobs do
  alias Ms2ex.{CharacterManager, Field, Items}

  def drop_rewards(mob) do
    if Ms2ex.roll(100) do
      # TODO calculate mesos drop rate
      mesos = Items.init(90_000_001, %{amount: Enum.random(2..800)})
      Field.add_mob_drop(mob, mesos)
    end

    if Ms2ex.roll(1) do
      merets = Items.init(90_000_004, %{amount: 20})
      Field.add_mob_drop(mob, merets)
    end

    if Ms2ex.roll(50) do
      sp_balls = Items.init(90_000_009, %{amount: 20})
      Field.add_mob_drop(mob, sp_balls)
    end

    if Ms2ex.roll(30) do
      ep_balls = Items.init(90_000_010, %{amount: 20})
      Field.add_mob_drop(mob, ep_balls)
    end

    # TODO get list of items dropped
  end

  def reward_exp(mob) do
    # TODO party exp
    CharacterManager.earn_exp(mob.last_attacker, mob.exp)
  end
end
