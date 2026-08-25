defmodule Ms2ex.Context.Mobs do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Storage.Tables.ExpTable

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
    player = mob.first_attacker || mob.last_attacker

    case exp_reward(mob) do
      :none -> :ok
      amount -> Managers.Character.cast(player, {:earn_exp, amount})
    end
  end

  # a fixed custom value; -1 means level-based, zero means no exp at all.
  # missing metadata falls back to the legacy flat reward
  defp exp_reward(mob) do
    level = get_in(mob.npc.metadata, [:basic, :level]) || 1

    case get_in(mob.npc.metadata, [:basic, :custom_exp]) do
      nil -> :none
      0 -> :none
      -1 -> ExpTable.mob_exp(level) || :none
      amount -> amount
    end
  end
end
