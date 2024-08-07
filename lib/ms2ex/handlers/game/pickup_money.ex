defmodule Ms2ex.GameHandlers.PickupMoney do
  require Logger

  alias Ms2ex.{Managers, Context, Context, Packets}

  import Packets.PacketReader

  def handle(packet, session) do
    {count, packet} = get_byte(packet)

    {:ok, character} = Managers.Character.lookup(session.character_id)

    pickup_items(packet, character, count)
  end

  defp pickup_items(_packet, _character, 0), do: :ok

  defp pickup_items(packet, character, count) do
    {object_id, packet} = get_int(packet)

    with {:ok, item} <- Context.Field.pickup_item(character, object_id),
         true <- Context.Items.mesos?(item) do
      Context.Wallets.update(character, :mesos, item.amount)
    end

    pickup_items(packet, character, count - 1)
  end
end
