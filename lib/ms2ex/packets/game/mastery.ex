defmodule Ms2ex.Packets.Mastery do
  @moduledoc """
  Life skill (mastery) frames: mastery value updates, grade reward claims,
  crafted item results and the error notices the client renders.
  """

  import Ms2ex.Packets.PacketWriter

  alias Ms2ex.Enums

  @modes %{
    update_mastery: 0x0,
    claim_reward: 0x1,
    get_crafted_item: 0x2,
    error: 0x3
  }

  def update_mastery(type, value) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update_mastery)
    |> put_byte(Enums.MasteryType.get_value(type))
    |> put_int(value)
    |> put_int()
  end

  def claim_reward(reward_box_id, items) do
    __MODULE__
    |> build()
    |> put_byte(@modes.claim_reward)
    |> put_int(reward_box_id)
    |> put_items(items)
  end

  def get_crafted_item(type, items) do
    __MODULE__
    |> build()
    |> put_byte(@modes.get_crafted_item)
    |> put_short(Enums.MasteryType.get_value(type))
    |> put_items(items)
  end

  def error(error) do
    __MODULE__
    |> build()
    |> put_byte(@modes.error)
    |> put_short(Enums.MasteryError.get_value(error))
  end

  defp put_items(packet, items) do
    packet
    |> put_int(length(items))
    |> reduce(items, fn item, packet ->
      packet
      |> put_int(item.item_id)
      |> put_short(item.rarity)
    end)
  end
end
