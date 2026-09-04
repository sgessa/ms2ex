defmodule Ms2ex.GuideRecordTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.GameHandlers
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ms2ex.Packets.PacketReader

  test "load serializes record count, id/step pairs, and trailing byte" do
    bytes = Packets.GuideRecord.load(%{101 => 3, 202 => 5})

    {opcode, packet} = get_short(bytes)
    {count, packet} = get_int(packet)
    {first_id, packet} = get_int(packet)
    {first_step, packet} = get_int(packet)
    {second_id, packet} = get_int(packet)
    {second_step, packet} = get_int(packet)

    assert opcode == 0x8B
    assert count == 2
    assert {first_id, first_step} == {101, 3}
    assert {second_id, second_step} == {202, 5}
    # trailing unknown byte
    assert packet == <<0>>
  end

  test "load accepts characters without records yet" do
    assert <<0x8B::little-16, 0::little-32, 0>> = Packets.GuideRecord.load(nil)
  end

  describe "recv" do
    setup do
      account =
        Repo.insert!(%Schema.Account{
          username: "guide_#{System.unique_integer([:positive])}",
          password_hash: "hash"
        })

      character =
        Repo.insert!(%Schema.Character{
          account_id: account.id,
          name: "Guide#{System.unique_integer([:positive])}",
          job: :knight,
          level: 1,
          map_id: 1,
          skin_color: {}
        })

      {:ok, pid} = Managers.Character.start(character)
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      session = %{character_id: character.id}
      %{character: character, session: session}
    end

    test "persists reported steps and merges later reports", %{
      character: character,
      session: session
    } do
      packet = build_client_packet(%{101 => 2})
      GameHandlers.GuideRecord.handle(packet, session)

      saved = Repo.get(Schema.Character, character.id)
      assert saved.guide_records == %{101 => 2}

      # a later report for another guide keeps the first one
      packet = build_client_packet(%{202 => 4})
      GameHandlers.GuideRecord.handle(packet, session)

      saved = Repo.get(Schema.Character, character.id)
      assert saved.guide_records == %{101 => 2, 202 => 4}
    end

    test "a later step overwrites the previous one", %{character: character, session: session} do
      packet = build_client_packet(%{101 => 2})
      GameHandlers.GuideRecord.handle(packet, session)

      packet = build_client_packet(%{101 => 6})
      GameHandlers.GuideRecord.handle(packet, session)

      saved = Repo.get(Schema.Character, character.id)
      assert saved.guide_records == %{101 => 6}
    end

    test "empty reports keep existing records", %{character: character, session: session} do
      packet = build_client_packet(%{101 => 2})
      GameHandlers.GuideRecord.handle(packet, session)

      GameHandlers.GuideRecord.handle(build_client_packet(%{}), session)

      saved = Repo.get(Schema.Character, character.id)
      assert saved.guide_records == %{101 => 2}
    end
  end

  defp build_client_packet(records) do
    count = map_size(records)

    entries =
      records
      |> Enum.map(fn {guide_id, step} ->
        <<guide_id::little-signed-32, step::little-signed-32>>
      end)
      |> :erlang.list_to_binary()

    <<count::little-signed-32>> <> entries
  end
end
