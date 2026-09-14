defmodule Ms2ex.Packets.PartySearch do
  import Ms2ex.Packets.PacketWriter

  alias Ms2ex.Enums

  def add(listing) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_listing(listing)
  end

  def remove(listing_id) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_long(listing_id)
  end

  def load(entries) do
    __MODULE__
    |> build()
    |> put_byte(0x2)
    |> put_int(Enum.count(entries))
    |> reduce(entries, fn entry, packet ->
      packet
      |> put_bool(true)
      |> put_listing(entry)
    end)
  end

  def error(error, category \\ 0) do
    error_code =
      if is_atom(error) do
        Enums.PartySearchError.get_value(error)
      else
        error
      end

    __MODULE__
    |> build()
    |> put_byte(0x4)
    |> put_byte(category)
    |> put_int(error_code)
  end

  defp put_listing(packet, listing) do
    packet
    |> put_long(listing.id)
    |> put_int(listing.party_id)
    |> put_int(0)
    |> put_int(0)
    |> put_ustring(listing.name)
    |> put_bool(listing.no_approval)
    |> put_int(listing.member_count)
    |> put_int(listing.size)
    |> put_long(listing.leader_account_id)
    |> put_long(listing.leader_character_id)
    |> put_ustring(listing.leader_name)
    |> put_long(listing.created_at)
  end
end
