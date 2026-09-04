defmodule Ms2ex.GameHandlers.RequestItemBox do
  @moduledoc """
  Opens an item box. The client addresses the box by its item id (not the
  inventory uid), sends how many copies to open and, for select boxes, the
  picked entry index as a string.
  """

  alias Ms2ex.Context
  alias Ms2ex.GameHandlers.Helper.ItemBox
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  import Packets.PacketReader

  def handle(packet, session) do
    {item_id, packet} = get_int(packet)
    {_unk, packet} = get_short(packet)
    {count, packet} = get_int(packet)
    {index, _packet} = index(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         %Schema.Item{} = item <- find_box(character, item_id),
         metadata = Context.Items.load_metadata(item),
         :ok <- validate_select(metadata, index) do
      ItemBox.open(session, character, metadata, max(count, 1), index)
    else
      _ -> :ok
    end
  end

  # a select box needs a valid picked index; plain boxes ignore it
  defp validate_select(item, index) do
    if Map.get(item, :function_name) == "SelectItemBox" and index < 0 do
      :error
    else
      :ok
    end
  end

  defp find_box(character, item_id) do
    character
    |> Managers.Inventory.list_items()
    |> Enum.find(&(&1.item_id == item_id))
  end

  # the index arrives as a string; non-numeric means "not a select open"
  defp index(packet) do
    {index_str, packet} = get_ustring(packet)

    case Integer.parse(index_str) do
      {value, _rest} -> {value, packet}
      :error -> {-1, packet}
    end
  end
end
