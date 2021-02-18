defmodule Ms2ex.Packets.Dismantle do
  import Ms2ex.Packets.PacketWriter

  @mode %{
    add: 0x1,
    remove: 0x2,
    show_rewards: 0x3,
    preview_results: 0x5
  }

  def add(uid, slot, amount) do
    __MODULE__
    |> build()
    |> put_byte(@mode.add)
    |> put_long(uid)
    |> put_short(slot)
    |> put_int(amount)
  end

  def remove(uid) do
    __MODULE__
    |> build()
    |> put_byte(@mode.remove)
    |> put_long(uid)
  end

  def preview_results(rewards) do
    length = Enum.count(rewards)

    __MODULE__
    |> build()
    |> put_byte(@mode.preview_results)
    |> put_int(length)
    |> reduce(rewards, fn {reward_id, amount}, packet ->
      packet
      |> put_int(reward_id)
      |> put_int(amount)
      |> put_int(amount)
    end)
  end

  def show_rewards(rewards) do
    length = Enum.count(rewards)

    __MODULE__
    |> build()
    |> put_byte(@mode.show_rewards)
    |> put_byte(0x1)
    |> put_int(length)
    |> reduce(rewards, fn {reward_id, amount}, packet ->
      packet
      |> put_int(reward_id)
      |> put_int(amount)
    end)
  end
end
