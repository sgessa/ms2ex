defmodule Ms2ex.GameHandlers.PremiumClub do
  alias Ms2ex.{CharacterManager, Packets, Wallets}
  alias Ms2ex.PremiumMemberships, as: Memberships

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Open
  defp handle_mode(0x1, _packet, session) do
    push(session, Packets.PremiumClub.open())
  end

  # Claim Items
  defp handle_mode(0x2, packet, session) do
    {benefit_id, _packet} = get_int(packet)
    # TODO grab data from \table\vipbenefititemtable.xml for item ID, quantity, rank
    # TODO only claim once a day
    push(session, Packets.PremiumClub.claim_item(benefit_id))
  end

  # Open Purchase Window
  defp handle_mode(0x3, _packet, session) do
    push(session, Packets.PremiumClub.show_purchase_window())
  end

  @packages %{
    3002 => %{cost: 490, expiration: 2_592_000},
    3004 => %{cost: 190, expiration: 604_800},
    3006 => %{cost: 90, expiration: 259_200}
  }

  # Purchase Membership
  defp handle_mode(0x4, packet, session) do
    {package_id, _packet} = get_int(packet)
    pkg = Map.get(@packages, package_id)
    account_id = session.account.id

    with true <- is_map(pkg),
         {:ok, character} <- CharacterManager.lookup(session.character_id),
         {:ok, wallet} <- Wallets.update(character, :merets, -pkg.cost),
         {:ok, membership} <- Memberships.create_or_extend(account_id, pkg.expiration) do
      session
      |> push(Packets.Wallet.update(wallet, :merets))
      |> push(Packets.PremiumClub.purchase_membership(package_id))
      |> push(Packets.PremiumClub.activate(character, membership))
    else
      _ -> session
    end
  end
end
