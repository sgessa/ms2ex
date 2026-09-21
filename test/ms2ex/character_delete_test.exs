defmodule Ms2ex.CharacterDeleteTest do
  # the handler is driven directly against the sandbox with a plain session
  # map; pushed packets are captured through the SenderSession stub
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.LoginHandlers.CharacterManagement
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "table:server.constants.xml" => %{
        character_destroy_division_level: 20,
        character_destroy_wait_second: 86_400
      }
    })

    Mimic.stub(Ms2ex.Net.SenderSession, :push, fn _session, packet ->
      send(self(), {:pushed, packet})
      :ok
    end)

    account = Repo.insert!(%Schema.Account{username: "delete_test", password_hash: "x"})

    %{
      account: account,
      low: insert_character(account, "DeleteLow", 1),
      high: insert_character(account, "DeleteHigh", 30)
    }
  end

  test "deleting a character below the division level removes it immediately", %{
    account: account,
    low: low
  } do
    CharacterManagement.handle(delete_packet(low.id), %{account: account})

    expected = delete_entry(low.id, 0)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, low.id) == nil
  end

  test "deleting a character at the division level schedules the deletion wait", %{
    account: account,
    high: high
  } do
    CharacterManagement.handle(delete_packet(high.id), %{account: account})

    character_id = high.id

    assert_received {:pushed, packet}

    <<0x0C::little-16, 0x5, ^character_id::little-integer-size(64), 0::little-integer-size(32),
      delete_time::little-signed-integer-size(64)>> = packet

    now = System.system_time(:second)
    assert delete_time in (now + 86_400 - 2)..(now + 86_400 + 2)

    reloaded = Repo.get(Schema.Character, high.id)
    assert reloaded != nil
    assert reloaded.delete_time == delete_time
    assert high.id in Enum.map(Context.Characters.list(account), & &1.id)
  end

  test "re-requesting an ongoing deletion re-acks the scheduled time", %{
    account: account,
    high: high
  } do
    {:ok, high} =
      Context.Characters.update(high, %{delete_time: System.system_time(:second) + 60})

    CharacterManagement.handle(delete_packet(high.id), %{account: account})

    expected = begin_delete(high.id, 10, high.delete_time)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, high.id) != nil
  end

  test "a pending deletion is finalized once the wait time has passed", %{
    account: account,
    high: high
  } do
    {:ok, high} = Context.Characters.update(high, %{delete_time: System.system_time(:second) - 1})

    CharacterManagement.handle(confirm_packet(high.id), %{account: account})

    expected = delete_entry(high.id, 0)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, high.id) == nil
  end

  test "cancelling a pending deletion clears the scheduled time", %{
    account: account,
    high: high
  } do
    {:ok, high} =
      Context.Characters.update(high, %{delete_time: System.system_time(:second) + 60})

    CharacterManagement.handle(cancel_packet(high.id), %{account: account})

    expected = cancel_delete(high.id, 0)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, high.id).delete_time == 0
  end

  test "cancelling a character without a pending deletion reports the error", %{
    account: account,
    low: low
  } do
    CharacterManagement.handle(cancel_packet(low.id), %{account: account})

    expected = cancel_delete(low.id, 8)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, low.id) != nil
  end

  test "deleting an unknown or foreign character reports it as already destroyed", %{
    account: account
  } do
    CharacterManagement.handle(delete_packet(404), %{account: account})

    expected = delete_entry(404, 1)
    assert_received {:pushed, ^expected}
  end

  test "a character with unread mail cannot cancel a pending deletion", %{
    account: account,
    high: high
  } do
    {:ok, high} =
      Context.Characters.update(high, %{delete_time: System.system_time(:second) + 60})

    Repo.insert!(%Schema.Mail{
      sender_id: 0,
      sender_name: "tester",
      receiver_id: high.id,
      receiver_type: :character,
      title: "unread",
      content: "",
      expires_at: DateTime.truncate(DateTime.add(DateTime.utc_now(), 86_400), :second)
    })

    CharacterManagement.handle(cancel_packet(high.id), %{account: account})

    expected = delete_entry(high.id, 7)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, high.id).delete_time != 0
  end

  test "a character with unread mail cannot be deleted", %{account: account, low: low} do
    Repo.insert!(%Schema.Mail{
      sender_id: 0,
      sender_name: "tester",
      receiver_id: low.id,
      receiver_type: :character,
      title: "unread",
      content: "",
      expires_at: DateTime.truncate(DateTime.add(DateTime.utc_now(), 86_400), :second)
    })

    CharacterManagement.handle(delete_packet(low.id), %{account: account})

    expected = delete_entry(low.id, 7)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, low.id) != nil
  end

  test "a guild member cannot be deleted", %{account: account, low: low, high: high} do
    {:ok, guild} = Context.Guilds.create(high, "DeleteTest", focus: :combat)
    {:ok, _member} = Context.Guilds.add_member(guild.id, low.id)

    CharacterManagement.handle(delete_packet(low.id), %{account: account})

    expected = delete_entry(low.id, 4)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, low.id) != nil
  end

  test "a guild leader cannot be deleted", %{account: account, low: low} do
    {:ok, _guild} = Context.Guilds.create(low, "DeleteTest", focus: :combat)

    CharacterManagement.handle(delete_packet(low.id), %{account: account})

    expected = delete_entry(low.id, 3)
    assert_received {:pushed, ^expected}
    assert Repo.get(Schema.Character, low.id) != nil
  end

  defp insert_character(account, name, level) do
    Repo.insert!(%Schema.Character{
      account_id: account.id,
      name: name,
      level: level,
      job: :knight,
      map_id: 1,
      skin_color: {{1, 2, 3, 255}, {1, 2, 3, 255}}
    })
  end

  defp delete_packet(character_id), do: management_packet(0x2, character_id)
  defp cancel_packet(character_id), do: management_packet(0x3, character_id)
  defp confirm_packet(character_id), do: management_packet(0x4, character_id)

  defp management_packet(mode, character_id) do
    <<mode, character_id::little-signed-integer-size(64)>>
  end

  defp delete_entry(character_id, error) do
    <<0x0C::little-16, 0x2, error::little-integer-size(32),
      character_id::little-signed-integer-size(64)>>
  end

  defp begin_delete(character_id, error, delete_time) do
    <<0x0C::little-16, 0x5, character_id::little-signed-integer-size(64),
      error::little-integer-size(32), delete_time::little-signed-integer-size(64)>>
  end

  defp cancel_delete(character_id, error) do
    <<0x0C::little-16, 0x6, character_id::little-signed-integer-size(64),
      error::little-integer-size(32)>>
  end
end
