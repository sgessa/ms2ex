defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  require Logger

  alias Ms2ex.{Field, Net, Packets, Registries}
  alias Ms2ex.Inventory, as: Items

  # import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

  def handle(_packet, %{character_id: character_id} = session) do
    {:ok, character} = Registries.Characters.lookup(character_id)
    character = Items.load_equips(character)
    Registries.Characters.update(character)

    {:ok, field_pid} = Field.find_or_create(character, session)

    # const hotbar = session.player.gameOptions.getHotbarById(0);

    # if (hotbar) {
    #     session.send(KeyTablePacket.sendHotbars(session.player.gameOptions));
    # }

    session
    |> Map.put(:field_pid, field_pid)
    |> push(Packets.PlayerStats.bytes(character))
    |> push(Packets.StatPoints.bytes(character))
    |> push(Packets.Emotion.bytes())
  end
end
