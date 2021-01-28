defmodule Ms2ex.GameHandlers.ResponseFieldEnter do
  require Logger

  alias Ms2ex.{Characters, Field, Net, Packets, Registries}

  import Net.SessionHandler, only: [push: 2]

  def handle(_packet, %{character_id: character_id} = session) do
    {:ok, character} = Registries.Characters.lookup(character_id)
    character = Characters.load_equips(character)

    {:ok, _pid} = Field.find_or_create(character, session)

    session
    |> push(Packets.PlayerStats.bytes(character))
    |> push(Packets.StatPoints.bytes(character))
    |> push(Packets.Emotion.bytes())
  end
end
