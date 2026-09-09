defmodule Ms2ex.Packets.PremiumClub do
  import Ms2ex.Packets.PacketWriter

  @mode %{
    activate: 0x0,
    open: 0x1,
    claim_item: 0x2,
    show_purchase_window: 0x3,
    purchase_membership: 0x4
  }

  def load_claimed(benefit_ids) do
    __MODULE__
    |> build()
    |> put_byte(@mode.open)
    |> put_int(length(benefit_ids))
    |> reduce(benefit_ids, fn benefit_id, packet -> put_int(packet, benefit_id) end)
  end

  def claim_item(benefit_id) do
    __MODULE__
    |> build()
    |> put_byte(@mode.claim_item)
    |> put_int(benefit_id)
  end

  def show_purchase_window() do
    __MODULE__
    |> build()
    |> put_byte(@mode.show_purchase_window)
    |> put_int()
  end

  def purchase_membership(package_id) do
    __MODULE__
    |> build()
    |> put_byte(@mode.purchase_membership)
    |> put_int(package_id)
  end

  def activate(character, %Ms2ex.Schema.PremiumMembership{} = membership) do
    activate(character, DateTime.to_unix(membership.expires_at))
  end

  def activate(character, expiration) when is_integer(expiration) do
    __MODULE__
    |> build()
    |> put_byte(@mode.activate)
    |> put_int(character.object_id)
    |> put_long(expiration)
  end
end
