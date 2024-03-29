defmodule Ms2ex.Mobs do
  alias Ms2ex.{CharacterManager, Field, Items}

  def drop_rewards(mob) do
    if Ms2ex.roll(70) do
      # TODO calculate mesos drop rate
      Field.add_mob_drop(mob, Items.mesos(Enum.random(2..800)))
    end

    if Ms2ex.roll(0.2) do
      Field.add_mob_drop(mob, Items.merets(20))
    end

    if Ms2ex.roll(50) do
      Field.add_mob_drop(mob, Items.sp(20))
    end

    if Ms2ex.roll(33) do
      Field.add_mob_drop(mob, Items.stamina(20))
    end

    # TODO get list of items dropped
  end

  def reward_exp(mob) do
    # TODO party exp
    CharacterManager.earn_exp(mob.last_attacker, mob.exp)
  end
end
