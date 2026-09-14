defmodule Ms2ex.PartySearchServerTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Managers.PartySearchServer
  alias Ms2ex.Types

  test "creates, filters, paginates, updates, and removes listings" do
    leader = %{id: System.unique_integer([:positive]), account_id: 1, name: "FinderLeader"}
    party = Types.Party.create(leader)
    name = "Dungeon #{System.unique_integer([:positive])}"

    assert {:ok, listing} = PartySearchServer.call({:create, party, name, true, 4})
    assert [^listing] = PartySearchServer.call({:fetch, name, :newest, 1})

    updated_party = %{party | members: [leader, %{id: 2, account_id: 2, name: "Member"}]}
    PartySearchServer.cast({:update, updated_party})

    assert %{member_count: 2} = PartySearchServer.call({:lookup, listing.id})
    assert :ok = PartySearchServer.call({:remove, listing.id})
    assert is_nil(PartySearchServer.call({:lookup, listing.id}))
  end

  test "rejects a listing when the party already reaches its recruit size" do
    members =
      for id <- 1..4 do
        %{id: id, account_id: id, name: "Member#{id}"}
      end

    party = %{Types.Party.create(hd(members)) | members: members}

    assert {:error, :max_member} =
             PartySearchServer.call({:create, party, "Full party", true, 4})
  end
end
