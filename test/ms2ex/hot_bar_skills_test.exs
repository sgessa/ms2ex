defmodule Ms2ex.HotBarSkillsTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Types

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "table:job.xml" => %{
        table: %{
          entries: %{
            10 => %{
              skills: %{
                basic: [%{main: 10_100_001, sub: []}, %{main: 10_100_011, sub: []}],
                awakening: []
              },
              base_skills: [10_100_001, 10_100_011]
            }
          }
        }
      },
      "skill:10100001" => %{
        id: 10_100_001,
        property: %{max_level: 12, type: 0},
        state: %{in_battle: true},
        levels: %{}
      },
      "skill:10100011" => %{
        id: 10_100_011,
        property: %{max_level: 10, type: 0},
        state: %{in_battle: true},
        levels: %{}
      },
      "skill:10100111" => %{
        id: 10_100_111,
        property: %{max_level: 5, type: 1},
        state: %{in_battle: true},
        levels: %{}
      }
    })

    account =
      Repo.insert!(%Schema.Account{
        username: "hb_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Hb#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    Repo.insert!(%Schema.CharacterConfig{character_id: character.id})

    tab = Context.Skills.add_tab(character, %{name: "Build 1"}) |> then(fn {:ok, t} -> t end)

    character = %{character | skill_tabs: [tab], active_skill_tab_id: tab.id}

    empty = List.duplicate(%Types.QuickSlot{}, 25)

    hot_bars = [
      Repo.insert!(%Schema.HotBar{character_id: character.id, active: true, quick_slots: empty}),
      Repo.insert!(%Schema.HotBar{character_id: character.id, active: false, quick_slots: empty})
    ]

    # the manager state as init builds it, plus the learned skills the
    # client-API computes from the character
    state = %{
      character_id: character.id,
      hot_bars: hot_bars,
      config: Context.CharacterConfigs.get(character.id)
    }

    # a learned passive: sits in the tab like any skill, but quick slots
    # must never pick it up
    Repo.insert!(%Schema.Skill{
      skill_tab_id: tab.id,
      skill_id: 10_100_111,
      level: 5,
      max_level: 5,
      sub_skills: [],
      rank: :basic
    })

    tab = %{tab | skills: Context.Skills.load_tab_skills(character, tab)}
    character = %{character | skill_tabs: [tab]}

    # the fill derives its own skill list from the character
    %{character: character, hot_bars: hot_bars, state: state}
  end

  test "a fresh character's active hot bar fills with learned active skills", %{
    character: character,
    hot_bars: hot_bars,
    state: state
  } do
    assert Enum.all?(hot_bars, fn bar -> Enum.all?(bar.quick_slots, &(&1.skill_id == 0)) end)

    {:reply, :ok, new_state} =
      Managers.CharacterConfig.handle_call({:update_hotbar_skills, character}, :from, state)

    active = Enum.find(new_state.hot_bars, & &1.active)
    bound = Enum.filter(active.quick_slots, &(&1.skill_id > 0))

    # the knight's learned actives land on the active bar — the learned
    # passive (10100111) must never appear
    refute bound == []
    assert Enum.all?(bound, &(&1.skill_id > 10_000_000 and &1.skill_id < 20_000_000))
    refute 10_100_111 in Enum.map(bound, & &1.skill_id)
    assert Enum.uniq(Enum.map(bound, & &1.skill_id)) == Enum.map(bound, & &1.skill_id)

    # only the active bar is written, and the fill lands in the database
    persisted = Context.HotBars.list(%Schema.Character{id: character.id})
    assert Enum.find(persisted, & &1.active).quick_slots == active.quick_slots

    assert Enum.find(persisted, &(!&1.active)).quick_slots ==
             List.duplicate(%Types.QuickSlot{}, 25)
  end

  test "a skill build save prunes unlearned slots and refills learned actives", %{
    character: character,
    state: state
  } do
    # a stale slot: the skill was placed but is no longer learned
    [active_bar | rest] = state.hot_bars

    stale_bar = %{
      active_bar
      | quick_slots:
          List.replace_at(active_bar.quick_slots, 2, %Types.QuickSlot{skill_id: 99_999_999})
    }

    state = %{state | hot_bars: [stale_bar | rest]}

    {:reply, :ok, new_state} =
      Managers.CharacterConfig.handle_call({:update_hotbar_skills, character}, :from, state)

    active = Enum.find(new_state.hot_bars, & &1.active)
    skill_ids_after = active.quick_slots |> Enum.map(& &1.skill_id) |> Enum.uniq()

    refute 99_999_999 in skill_ids_after
    assert 10_100_001 in skill_ids_after
    assert 10_100_011 in skill_ids_after
  end
end
