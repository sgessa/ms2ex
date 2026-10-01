defmodule Ms2ex.WalletsTest do
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Context
  alias Ms2ex.Schema

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "table:server.constants.xml" => %{
        honor_token_max: 100,
        karma_token_max: 75_000,
        lu_token_max: 2_000,
        habi_token_max: 35_000
      }
    })

    account =
      Repo.insert!(%Schema.Account{
        username: "wallet_#{System.unique_integer([:positive])}",
        password_hash: "x"
      })

    character =
      Repo.insert!(%Schema.Character{
        account_id: account.id,
        name: "Wallet#{System.unique_integer([:positive])}",
        job: :knight,
        level: 10,
        map_id: 1,
        skin_color: {}
      })

    character = %{character | sender_session_pid: self()}

    Repo.insert!(%Schema.Wallet{
      character_id: character.id,
      mesos: 1_000,
      valor_tokens: 90
    })

    Repo.insert!(%Schema.AccountWallet{account_id: account.id, merets: 500})

    %{account: account, character: character}
  end

  test "credits clamp at the currency cap and report the overflow", %{character: character} do
    # honor_token_max is stubbed to 100; the wallet holds 90
    {:ok, wallet} = Context.Wallets.update(character, :valor_tokens, 50)

    assert wallet.valor_tokens == 100
    assert Repo.reload!(wallet).valor_tokens == 100

    assert_received {:push, packet}
    # opcode + token packet: type byte, balance long, applied delta long,
    # int, overflow long
    assert packet ==
             <<0x3C::little-16, 0x03, 100::little-64, 10::little-64, 0::little-32, 40::little-64>>
  end

  test "credits within the cap apply fully", %{character: character} do
    {:ok, wallet} = Context.Wallets.update(character, :valor_tokens, 5)

    assert wallet.valor_tokens == 95
    assert_received {:push, _packet}
  end

  test "mesos are unbounded", %{character: character} do
    {:ok, wallet} = Context.Wallets.update(character, :mesos, 2_000_000_000)

    assert wallet.mesos == 2_000_000_000 + 1_000
  end

  test "debits beyond the balance fail without touching the wallet", %{character: character} do
    {:error, :insufficient_funds} = Context.Wallets.update(character, :mesos, -2_000)

    {:error, :insufficient_funds} = Context.Wallets.debit(character, :mesos, 2_000)

    assert Repo.get_by!(Schema.Wallet, character_id: character.id).mesos == 1_000
    refute_received {:push, _packet}
  end

  test "account wallet debits fail wholesale", %{character: character} do
    {:error, :insufficient_funds} = Context.Wallets.debit(character, :merets, 600)

    assert Repo.get_by!(Schema.AccountWallet, account_id: character.account_id).merets == 500
  end

  test "can_add clamps credits at the cap and debits at zero", %{character: character} do
    assert Context.Wallets.can_add(character, :valor_tokens, 50) == 10
    assert Context.Wallets.can_add(character, :valor_tokens, -50) == -50
    assert Context.Wallets.can_add(character, :valor_tokens, -200) == -90
    assert Context.Wallets.can_add(character, :mesos, 50) == 50
  end

  test "set clamps into the cap", %{character: character} do
    {:ok, wallet} = Context.Wallets.set(character, :valor_tokens, 500)

    assert wallet.valor_tokens == 100
  end

  test "token caps resolve from the client table", %{character: character} do
    assert Context.Wallets.cap(:valor_tokens) == 100
    assert Context.Wallets.cap(:trevas) == 75_000
    assert Context.Wallets.cap(:rues) == 2_000
    assert Context.Wallets.cap(:havi_fruits) == 35_000
    assert Context.Wallets.cap(:meso_tokens) == 100_000
    assert Context.Wallets.cap(:mesos) == 9_223_372_036_854_775_807
  end
end
