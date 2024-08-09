defmodule Ms2ex.Context.Mobs do
  alias Ms2ex.Managers
  alias Ms2ex.Context

  def drop_rewards(mob) do
    if Ms2ex.roll(70) do
      # TODO calculate mesos drop rate
      Context.Field.add_mob_drop(mob, Context.Items.mesos(Enum.random(2..800)))
    end

    if Ms2ex.roll(0.2) do
      Context.Field.add_mob_drop(mob, Context.Items.merets(20))
    end

    if Ms2ex.roll(50) do
      Context.Field.add_mob_drop(mob, Context.Items.sp(20))
    end

    if Ms2ex.roll(33) do
      Context.Field.add_mob_drop(mob, Context.Items.stamina(20))
    end

    # TODO get list of items dropped
  end

  def reward_exp(mob) do
    # TODO party exp
    # TODO get mob exp (instead of hardcoded 10)
    Managers.Character.cast(mob.last_attacker, {:earn_exp, 10})
  end
end
