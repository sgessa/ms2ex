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
    0x10 => "RESPONSE_FIELD_ENTER",
    0x11 => "USER_CHAT",
    0x12 => "USER_SYNC",
    0x13 => "EMOTE",
    0x16 => "EQUIP_ITEM",
    0x17 => "INVENTORY",
    0x19 => "USE_ITEM",
    0x22 => "NPC_TALK",
    0x1C => "PICKUP_ITEM",
    0x1D => "PICKUP_MONEY",
    0x20 => "SKILL",
    0x25 => "JOB",
    0x26 => "VIBRATE",
    0x29 => "QUEST",
    0x2C => "PARTY",
    0x30 => "FRIEND",
    0x37 => "REQUEST_CUBE",
    0x39 => "UGC",
    0x3B => "KEY_TABLE",
    0x3C => "REQUEST_CHANGE_CHANNEL",
    0x41 => "RIDE",
    0x42 => "RIDE_SYNC",
    0x49 => "TAXI",
    0x4B => "REQUEST_WORLD_MAP",
    0x4D => "GROUP_CHAT",
    0x56 => "SEND_LOG",
    0x5B => "DISMANTLE",
    0x6A => "USER_ENV",
    0x6C => "INSIGNIA",
    0x6D => "REQUEST_CHANGE_FIELD",
    0x83 => "GLOBAL_FACTOR",
    0x8F => "PREMIUM_CLUB",
    0xA3 => "SKILL_BOOK",
    0xB2 => "RESPONSE_SERVER_ENTER",
    0xBB => "FILE_HASH",
    0xB9 => "CHAT_STICKER"
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
    0x10 => "GAME_TO_GAME",
    0x11 => "RESPONSE_TIME_SYNC",
    0x13 => "REQUEST_CLIENT_SYNC_TICK",
    0x14 => "SYNC_NUMBER",
    0x15 => "SERVER_ENTER",
    0x16 => "REQUEST_FIELD_ENTER",
    0x17 => "FIELD_ADD_USER",
    0x18 => "FIELD_REMOVE_OBJECT",
    0x19 => "FIELD_ENTRANCE",
    0x25 => "EQUIP_ITEM",
    0x26 => "UNEQUIP_ITEM",
    0x1C => "USER_SYNC",
    0x1D => "USER_CHAT",
    0x1F => "EMOTE",
    0x21 => "INVENTORY_ITEM",
    0x23 => "MARKET_INVENTORY",
    0x24 => "FURNISHING_INVENTORY",
    0x2B => "FIELD_ADD_ITEM",
    0x2C => "FIELD_REMOVE_ITEM",
    0x2D => "FIELD_PICKUP_ITEM",
    0x2F => "STATS",
    0x30 => "USER_BATTLE",
    0x38 => "EXPERIENCE",
    0x39 => "LEVEL_UP",
    0x3A => "MESOS",
    0x3B => "MERETS",
    0x3C => "WALLET",
    0x3D => "SKILL_USE",
    0x3F => "SKILL_SYNC",
    0x40 => "SKILL_CANCEL",
    0x3E => "SKILL_DAMAGE",
    0x46 => "STAT_POINTS",
    0x47 => "CHARACTER_CREATE",
    0x48 => "BUFF",
    0x49 => "ADD_PORTAL",
    0x4A => "JOB",
    0x4D => "REGION_SKILL",
    0x54 => "PARTY",
    0x56 => "FIELD_ADD_NPC",
    0x57 => "FIELD_REMOVE_NPC",
    0x59 => "CONTROL_NPC",
    0x60 => "MOVE_CHARACTER",
    0x63 => "FRIEND",
    0x65 => "ADD_INTERACT_OBJECTS",
    0x67 => "FALL_DAMAGE",
    0x6B => "RESPONSE_CUBE",
    0x6D => "UGC",
    0x71 => "KEY_TABLE",
    0x77 => "VIBRATE",
    0x7B => "RESPONSE_RIDE",
    0x7C => "RIDE_SYNC",
    0x7F => "LOAD_UGC_MAP",
    0x80 => "PROXY_GAME_OBJ",
    0x82 => "TAXI",
    0x86 => "WORLD_MAP",
    0x8D => "GROUP_CHAT",
    0x98 => "DISMANTLE",
    0xAA => "USER_ENV",
    0xA9 => "DYNAMIC_CHANNEL",
    0xB3 => "INSIGNIA",
    0xB5 => "BANNER_LIST",
    0xBA => "CHARACTER_MAX_COUNT",
    0xC6 => "FISHING",
    0xC8 => "NPS_INFO",
    0xED => "PREMIUM_CLUB",
    0xCC => "FIELD_PROPERTY",
    0x10E => "SKILL_BOOK",
    0x11B => "LOGIN_REQUIRED",
    0x11E => "PRESTIGE",
    0x128 => "CHAT_STICKER",
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

  def opcode_to_name(:send, :handshake, _base), do: "HANDSHAKE"

  def opcode_to_name(:send, opcode, base) do
    Map.get(@send_ops, opcode) || inspect(opcode, base: base)
  end

  def recv_ops(), do: @recv_ops
  def send_ops(), do: @send_ops
end
