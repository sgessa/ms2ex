defmodule Ms2ex.Commands do
  alias Ms2ex.{Inventory, Metadata, Net, Packets}

  import Net.SessionHandler, only: [push: 2, push_notice: 3]

  def handle(["item" | ids], character, session) do
    Enum.reduce(ids, session, fn item_id, session ->
      with {item_id, _} <- Integer.parse(item_id),
           {:ok, meta} <- Metadata.Items.lookup(item_id) do
        item = %Inventory.Item{item_id: item_id, metadata: meta}
        add_item(character, item, session)
      else
        _ ->
          push_notice(session, character, "Invalid Item #{item_id}")
      end
    end)
  end

  def handle(_args, character, session) do
    push_notice(session, character, "Command not found.")
  end

  defp add_item(character, item, session) do
    case Inventory.add_item(character, item) do
      {:ok, result} -> push(session, Packets.InventoryItem.add_item(result))
      _ -> session
    end
  end
end
