defmodule Ms2ex.SystemNotice do
  @notices [
    insufficient_merets: 0x35,
    unable_to_whisper: 0x4C,
    used_world_chat_voucher: 0xAE2
  ]

  def values(), do: @notices

  def from_name(name), do: Keyword.get(@notices, name)
end
