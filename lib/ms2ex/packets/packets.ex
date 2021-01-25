defmodule Ms2ex.Packets do
  @recv_ops %{
    0x1 => "RESPONSE_VERSION",
    0x3 => "RESPONSE_LOGIN",
    0x4 => "RESPONSE_KEY",
    0x9 => "CHARACTER_MANAGEMENT",
    0xB => "REQUEST_TIME_SYNC",
    0xC => "RESPONSE_CLIENT_SYNC_TICK",
    0xD => "REQUEST_QUIT",
    0xF => "LOAD_UGC_MAP",
    0x12 => "USER_SYNC",
    0xB2 => "RESPONSE_SERVER_ENTER",
    0xBB => "FILE_HASH",
    0x10 => "RESPONSE_FIELD_ENTER",
    0x39 => "UGC",
    0x3B => "KEY_TABLE",
    0x56 => "SEND_LOG",
    0x83 => "GLOBAL_FACTOR"
  }

  @send_ops %{
    0x4 => "REQUEST_KEY",
    0x9 => "REQUEST_LOGIN",
    0xA => "LOGIN_RESULT",
    0xB => "SERVER_LIST",
    0xC => "CHARACTER_LIST",
    0xD => "MOVE_RESULT",
    0xE => "LOGIN_TO_GAME",
    0xF => "GAME_TO_LOGIN",
    0x11 => "RESPONSE_TIME_SYNC",
    0x13 => "REQUEST_CLIENT_SYNC_TICK",
    0x14 => "SYNC_NUMBER",
    0x15 => "SERVER_ENTER",
    0x16 => "REQUEST_FIELD_ENTER",
    0x17 => "FIELD_ADD_USER",
    0x19 => "FIELD_ENTRANCE",
    0x1C => "USER_SYNC",
    0x1F => "EMOTION",
    0x21 => "ITEM_INVENTORY",
    0x23 => "MARKET_INVENTORY",
    0x24 => "FURNISHING_INVENTORY",
    0x2F => "PLAYER_STATS",
    0x46 => "STAT_POINTS",
    0x63 => "BUDDY_LIST",
    0x6D => "UGC",
    0x71 => "KEY_TABLE",
    0x7F => "LOAD_UGC_MAP",
    0x80 => "PROXY_GAME_OBJ",
    0xAA => "USER_ENV",
    0xA9 => "DYNAMIC_CHANNEL",
    0xB5 => "BANNER_LIST",
    0xBA => "CHARACTER_MAX_COUNT",
    0xC6 => "FISHING",
    0xC8 => "NPS_INFO",
    0x11B => "LOGIN_REQUIRED",
    0x11E => "PRESTIGE",
    0x132 => "UNKNOWN_SYNC"
  }

  def name_to_opcode(:send, name) do
    case Enum.find(@send_ops, fn {_k, v} -> name == v end) do
      {opcode, _name} -> opcode
      _ -> nil
    end
  end

  def opcode_to_name(type, opcode, base \\ :hex)

  def opcode_to_name(:recv, opcode, base) do
    Map.get(@recv_ops, opcode) || inspect(opcode, base: base)
  end

  def opcode_to_name(:send, opcode, base) do
    Map.get(@send_ops, opcode) || inspect(opcode, base: base)
  end

  def recv_ops(), do: @recv_ops
  def send_ops(), do: @send_ops
end
