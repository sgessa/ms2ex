defmodule Ms2ex.Packets.ProxyGameObj do
  alias Ms2ex.Packets
  alias Ms2ex.Users.Character

  import Packets.PacketWriter

  @modes %{
    load_player: 0x3,
    update_player: 0x5
  }

  def load_player(character) do
    real_job_id = Character.real_job_id(character)

    __MODULE__
    |> build()
    |> put_byte(@modes.load_player)
    |> put_int(character.object_id)
    |> put_long(character.account_id)
    |> put_long(character.id)
    |> put_ustring(character.name)
    |> put_ustring(character.profile_url)
    |> put_ustring(character.motto)
    |> put_byte()
    |> put_coord(character.position)
    |> put_short(character.level)
    |> put_short(real_job_id)
    |> put_int(Character.job_id(character))
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_ustring(character.home_name)
    |> put_int()
    |> put_short()
    |> Packets.CharacterList.put_trophies(character.trophies)
  end
end
