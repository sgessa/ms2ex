defmodule Ms2ex.StateSkillCostTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @cast_id 9001
  @drain_cost %{spirit: 10, stamina: 5}

  # ---- cast gating & consumption ----

  test "cast_state_skill consumes spirit and stamina" do
    character = character()
    skill_cast = skill_cast(character)

    assert {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 16)
    assert character.stats.spirit_cur == 90
    assert character.stats.stamina_cur == 95
  end

  test "cast_state_skill is rejected without enough resources" do
    character = character(%{stats: %{spirit_cur: 5, spirit_max: 100}})
    skill_cast = skill_cast(character)

    assert :error = Character.Skill.cast_state_skill(character, skill_cast, 16)
    assert character.stats.spirit_cur == 5
  end

  # ---- drain ticks ----

  test "state_skill_tick drains again while resources last" do
    character = character()
    skill_cast = skill_cast(character)

    {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 16)
    character = activate(character, skill_cast, 16)

    character = Character.Skill.state_skill_tick(character, @cast_id)

    assert character.stats.spirit_cur == 80
    assert character.stats.stamina_cur == 90
    assert character.state_skill.skill_cast.id == @cast_id
  end

  test "state_skill_tick cancels the stance when resources run out" do
    character = character()
    skill_cast = skill_cast(character)

    {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 16)
    character = activate(character, skill_cast, 16)
    character = put_in(character.stats.spirit_cur, 3)

    character = Character.Skill.state_skill_tick(character, @cast_id)

    assert character.state_skill == nil
    assert character.stats.spirit_cur == 3
  end

  test "state_skill_tick cancels the stance when the actor is dead" do
    character = character()
    skill_cast = skill_cast(character)

    {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 16)
    character = activate(character, skill_cast, 16)
    character = Map.put(character, :dead?, true)

    character = Character.Skill.state_skill_tick(character, @cast_id)

    assert character.state_skill == nil
  end

  test "state_skill_tick drains while the synced actor state matches" do
    character = character()
    skill_cast = swim_skill_cast(character)

    {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 28)
    character = activate(character, skill_cast, 28)
    character = Map.put(character, :animation, 28)

    character = Character.Skill.state_skill_tick(character, @cast_id)

    # cast consumed 5, the tick drains another 5
    assert character.stats.stamina_cur == 90
    assert character.state_skill.skill_cast.id == @cast_id
  end

  test "state_skill_tick cancels once the actor leaves the skill state" do
    character = character()
    skill_cast = swim_skill_cast(character)

    {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 28)
    character = activate(character, skill_cast, 28)
    character = Map.put(character, :animation, 28)

    # the actor released the boost: user syncs no longer report swimming
    character = Map.put(character, :animation, 0)

    character = Character.Skill.state_skill_tick(character, @cast_id)

    assert character.state_skill == nil
    assert character.stats.stamina_cur == 95
  end

  test "state_skill_tick ignores stale cast ids" do
    character = character()
    skill_cast = skill_cast(character)

    {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 16)
    character = activate(character, skill_cast, 16)

    character = Character.Skill.state_skill_tick(character, @cast_id + 1)

    assert character.stats.spirit_cur == 90
    assert character.state_skill.skill_cast.id == @cast_id
  end

  # ---- cancellation ----

  test "cancel_state_skill drops the active stance" do
    character = character()
    skill_cast = skill_cast(character)

    {:ok, character} = Character.Skill.cast_state_skill(character, skill_cast, 16)
    character = activate(character, skill_cast, 16)

    cancelled = Character.Skill.cancel_state_skill(character)

    assert %{state_skill: nil} = cancelled
    # the cast manager is stopped with the stance
    assert Process.whereis(:"skill_cast:#{@cast_id}") == nil
  end

  test "cancel_state_skill tolerates missing state-skill tracking" do
    # a character whose manager state predates the tracking has no key
    character = character()
    refute Map.has_key?(character, :state_skill)
    assert character == Character.Skill.cancel_state_skill(character)
  end

  # ---- integration: the character manager owns the drain loop ----

  test "the character manager validates, consumes, and refreshes without double-drain" do
    character = character(%{id: System.unique_integer([:positive])})
    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    skill_cast = skill_cast(character)

    assert {:ok, first} =
             Managers.Character.call(character, {:cast_state_skill, skill_cast, 16})

    assert first.stats.spirit_cur == 90

    # a repeated packet for the same stance must not consume again
    assert {:ok, refreshed} =
             Managers.Character.call(character, {:cast_state_skill, skill_cast, 16})

    assert refreshed.stats.spirit_cur == 90

    # a new stance on a different cast id replaces the running one
    other = skill_cast(character, @cast_id + 7)

    assert {:ok, switched} = Managers.Character.call(character, {:cast_state_skill, other, 16})
    assert switched.stats.spirit_cur == 80
  end

  test "the character manager persists regular skill spirit costs and resumes regen" do
    Mimic.stub(Ms2ex.Storage, :get, fn _set, _id -> nil end)

    character =
      character(%{
        id: System.unique_integer([:positive]),
        stats: %{
          health_max: 1000,
          health_cur: 1000,
          spirit_max: 100,
          spirit_cur: 100,
          sp_regen_cur: 5,
          sp_regen_interval_cur: 50,
          stamina_max: 100,
          stamina_cur: 100,
          stamina_regen_cur: 0,
          hp_regen_interval_cur: 1000,
          stamina_regen_interval_cur: 1000
        }
      })

    {:ok, pid} = Managers.Character.start(character)

    on_exit(fn ->
      Managers.SkillCast.stop(@cast_id)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    assert {:ok, casted} =
             Managers.Character.call(character, {:cast_skill, skill_cast(character)})

    assert casted.stats.spirit_cur == 90
    assert {:ok, persisted} = Managers.Character.call(character, :lookup)
    assert persisted.stats.spirit_cur == 90

    regen_to = eventually(fn -> spirit_of(character) end, &(&1 >= 100), 2_000)

    assert regen_to == 100
  end

  test "repeated spirit drains arm regen only once before the first tick" do
    character =
      character(%{
        stats: %{
          health_max: 1000,
          health_cur: 1000,
          spirit_max: 100,
          spirit_cur: 100,
          sp_regen_cur: 1,
          sp_regen_interval_cur: 20,
          stamina_max: 100,
          stamina_cur: 100,
          hp_regen_interval_cur: 1000,
          stamina_regen_interval_cur: 1000
        }
      })

    character = Character.Stats.decrease(character, :spirit, 10, [])
    assert character.regen_spirit? == true

    _character = Character.Stats.decrease(character, :spirit, 10, [])

    refute_receive {:regen, :spirit}, 50
    assert_receive {:regen, :spirit}, 150
  end

  test "the character manager rejects a state-skill cast without resources" do
    character =
      character(%{
        id: System.unique_integer([:positive]),
        stats: %{
          spirit_max: 100,
          spirit_cur: 0,
          stamina_max: 100,
          stamina_cur: 100,
          sp_regen_interval_cur: 1000,
          stamina_regen_interval_cur: 1000,
          hp_regen_interval_cur: 1000
        }
      })

    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    assert :error =
             Managers.Character.call(character, {:cast_state_skill, skill_cast(character), 16})
  end

  # ---- drain cadence ----

  test "drain_interval uses the projected motion sequence speed" do
    skill_cast = %Types.SkillCast{
      skill_id: 15_000_220,
      skill_level: 1,
      meta: %{
        levels: %{
          "1" => %{
            consume: %{stat: @drain_cost},
            motions: [%{motion_property: %{sequence_speed: 0.6}, attacks: []}]
          }
        }
      }
    }

    assert Types.SkillCast.drain_interval(skill_cast) == 600
  end

  test "drain_interval falls back without projected sequence speed" do
    skill_cast = %Types.SkillCast{
      skill_id: 15_000_220,
      skill_level: 1,
      meta: %{levels: %{"1" => %{consume: %{stat: @drain_cost}, motions: [%{attacks: []}]}}}
    }

    assert Types.SkillCast.drain_interval(skill_cast) == 1000
  end

  test "drain_interval falls back on zero speed or missing motions" do
    zero = %Types.SkillCast{
      skill_id: 15_000_220,
      skill_level: 1,
      meta: %{
        levels: %{
          "1" => %{
            consume: %{stat: @drain_cost},
            motions: [%{motion_property: %{sequence_speed: 0.0}, attacks: []}]
          }
        }
      }
    }

    assert Types.SkillCast.drain_interval(zero) == 1000

    motionless = %Types.SkillCast{
      skill_id: 15_000_220,
      skill_level: 1,
      meta: %{levels: %{"1" => %{consume: %{stat: @drain_cost}}}}
    }

    assert Types.SkillCast.drain_interval(motionless) == 1000
  end

  # ---- helpers ----

  defp character(overrides \\ %{}) do
    stats = %{
      health_max: 1000,
      health_cur: 1000,
      spirit_max: 100,
      spirit_cur: 100,
      stamina_max: 100,
      stamina_cur: 100,
      sp_regen_interval_cur: 1000,
      stamina_regen_interval_cur: 1000,
      hp_regen_interval_cur: 1000
    }

    %Schema.Character{
      id: System.unique_integer([:positive]),
      object_id: System.unique_integer([:positive]),
      map_id: 2000,
      channel_id: 1,
      sender_session_pid: self(),
      stats: stats
    }
    |> Map.merge(overrides)
  end

  defp skill_cast(caster, id \\ @cast_id) do
    %Types.SkillCast{
      id: id,
      skill_id: 15_000_220,
      skill_level: 1,
      caster: caster,
      meta: %{levels: %{"1" => %{consume: %{stat: @drain_cost}, skills: []}}}
    }
  end

  defp swim_skill_cast(caster) do
    %Types.SkillCast{
      id: @cast_id,
      skill_id: 20_000_001,
      skill_level: 1,
      caster: caster,
      meta: %{
        state: %{state: 28},
        levels: %{"1" => %{consume: %{stat: %{stamina: 5}}}}
      }
    }
  end

  defp activate(character, skill_cast, state) do
    Map.put(character, :state_skill, %{skill_cast: skill_cast, state: state})
  end

  defp spirit_of(character) do
    case Managers.Character.call(character, :lookup) do
      {:ok, %{stats: %{spirit_cur: cur}}} -> cur
      _ -> -1
    end
  end

  defp eventually(produce, done?, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_eventually(produce, done?, deadline)
  end

  defp do_eventually(produce, done?, deadline) do
    value = produce.()

    if done?.(value) or System.monotonic_time(:millisecond) > deadline do
      value
    else
      Process.sleep(25)
      do_eventually(produce, done?, deadline)
    end
  end
end
