defmodule Ms2ex.StatsRegenTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character
  alias Ms2ex.Schema

  @interval 50
  @regen 10

  test "regen applies the regen amount to a living character below max" do
    character = character(stats: [stamina_cur: 40, stamina_max: 100])

    character = Character.Stats.regen(character, :stamina)

    assert character.stats.stamina_cur == 50
    assert character.regen_stamina? == true
  end

  test "regen stops once the stat is full" do
    character = character(stats: [stamina_cur: 95, stamina_max: 100])

    # first tick tops off (and schedules one more); the next tick is a no-op
    character = Character.Stats.regen(character, :stamina)
    assert character.stats.stamina_cur == 100

    character = Character.Stats.regen(character, :stamina)
    assert character.stats.stamina_cur == 100
    assert character.regen_stamina? == false
  end

  test "the dead do not regenerate" do
    character =
      character(stats: [stamina_cur: 40, stamina_max: 100])
      |> Map.put(:dead?, true)

    character = Character.Stats.regen(character, :stamina)

    assert character.stats.stamina_cur == 40
    assert character.regen_stamina? == false
  end

  test "regen caps at max" do
    character = character(stats: [stamina_cur: 97, stamina_max: 100])

    assert Character.Stats.regen(character, :stamina).stats.stamina_cur == 100
  end

  test "consumption suspends regen for the wait period" do
    character = character(stats: [stamina_cur: 100, stamina_max: 100])
    character = Character.Stats.decrease(character, :stamina, 40, [])

    assert character.stats.stamina_cur == 60
    assert Map.has_key?(character.regen_waits, :stamina)

    # the regen tick inside the wait window is deferred, not lost
    character = Character.Stats.regen(character, :stamina)

    assert character.stats.stamina_cur == 60
    assert character.regen_stamina? == true
  end

  test "regen resumes once the wait expires" do
    character = character(stats: [stamina_cur: 60, stamina_max: 100])
    character = Character.Stats.decrease(character, :stamina, 10, [])
    assert character.stats.stamina_cur == 50

    # pretend the wait already elapsed
    character =
      Map.put(character, :regen_waits, %{
        stamina: System.monotonic_time(:millisecond) - 1
      })

    character = Character.Stats.regen(character, :stamina)

    assert character.stats.stamina_cur == 60
  end

  test "the character manager resumes regen after a stamina drain" do
    character = character(id: System.unique_integer([:positive]), stats: [stamina_cur: 100])
    {:ok, pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    Managers.Character.cast(character, {:consume_stat, :stamina, 40})
    assert {:ok, %{stats: %{stamina_cur: 60}}} = Managers.Character.call(character, :lookup)

    # the regen cycle re-arms itself until the stat is full
    regen_to = eventually(fn -> stamina_of(character) end, &(&1 >= 100), 5_000)

    assert regen_to == 100
  end

  defp stamina_of(character) do
    case Managers.Character.call(character, :lookup) do
      {:ok, %{stats: %{stamina_cur: cur}}} -> cur
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

  test "regen wait comes from the server constants table" do
    Mimic.stub(Ms2ex.Storage, :get, fn :table, "server.constants.xml" ->
      %{recovery_ep_wait_tick: 250}
    end)

    before = System.monotonic_time(:millisecond)
    character = character(stats: [stamina_cur: 100, stamina_max: 100])
    character = Character.Stats.decrease(character, :stamina, 40, [])

    assert character.regen_waits.stamina in (before + 250)..(System.monotonic_time(:millisecond) +
                                                               250)
  end

  test "regen wait falls back when the constants table is absent" do
    Mimic.stub(Ms2ex.Storage, :get, fn :table, "server.constants.xml" -> nil end)

    before = System.monotonic_time(:millisecond)
    character = character(stats: [stamina_cur: 100, stamina_max: 100])
    character = Character.Stats.decrease(character, :stamina, 40, [])

    assert character.regen_waits.stamina in (before + 1_000)..(System.monotonic_time(:millisecond) +
                                                                 1_000)
  end

  defp character(overrides) do
    {stat_overrides, overrides} = Keyword.pop(overrides, :stats, [])

    stats =
      %{
        health_max: 1000,
        health_cur: 1000,
        hp_regen_cur: 5,
        hp_regen_interval_cur: @interval,
        spirit_max: 100,
        spirit_cur: 100,
        sp_regen_cur: 5,
        sp_regen_interval_cur: @interval,
        stamina_max: 100,
        stamina_cur: 100,
        stamina_regen_cur: @regen,
        stamina_regen_interval_cur: @interval
      }
      |> Map.merge(Map.new(stat_overrides))

    %Schema.Character{
      id: System.unique_integer([:positive]),
      object_id: System.unique_integer([:positive]),
      map_id: 2000,
      channel_id: 1,
      sender_session_pid: self(),
      stats: stats
    }
    |> Map.merge(Map.new(overrides))
  end
end
