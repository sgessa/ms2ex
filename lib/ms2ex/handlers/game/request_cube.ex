defmodule Ms2ex.GameHandlers.RequestCube do
  require Logger
  alias Ms2ex.{Managers, Context, Packets}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  # @hold_cube 0x01
  # @buy_plot 0x02
  # @forfeit_plot 0x06
  # @extend_plot 0x09
  # @place_cube 0x0A
  @remove_cube 0x0C
  # @rotate_cube 0x0E
  # @replace_cube 0x0F
  # @liftup_object 0x11
  # @liftup_drop 0x12
  # @set_home_name 0x15
  # @set_passcode 0x18
  # @vote_home 0x19
  # @set_home_message 0x1D
  # @clear_cubes 0x1F
  # @load_unknown 0x23
  # @increase_area 0x25
  # @decrease_area 0x26
  # @design_rank_reward 0x28
  # @enable_permission 0x2A
  # @set_permission 0x2B
  # @increase_height 0x2C
  # @decrease_height 0x2D
  # @save_home 0x2E
  # @load_home 0x2F
  # @confirm_load_home 0x30
  # @kick_out 0x31
  # @set_background 0x32
  # @set_lighting 0x33
  # @set_camera 0x36
  # @save_blueprint 0x40
  # @load_blueprint 0x41

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  def handle_mode(@remove_cube, _packet, session) do
    with {:ok, character} <- Managers.Character.lookup(session.character_id) do
      Context.Field.broadcast(character, Packets.UserBattle.set_stance(character, false))
      push(session, Packets.ResponseCube.drop(character))
    end
  end

  def handle_mode(_, _, _) do
    Logger.warning("Unhandled request cube mode")
  end
end
