defmodule Ms2ex.SystemNotice do
  import EctoEnum

  defenum(Notice,
    insufficient_merets: 0x35,
    unable_to_whisper: 0x4C,
    used_world_chat_voucher: 0xAE2
  )

  def from_name(name), do: Keyword.get(Notice.__enum_map__(), name)
end
