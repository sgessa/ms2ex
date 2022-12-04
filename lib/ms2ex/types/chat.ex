defmodule Ms2ex.Chat do
  @types [
    all: 0,
    whisper_from: 3,
    whisper_to: 4,
    whisper_fail: 5,
    whisper_reject: 6,
    party: 7,
    guild: 8,
    notice: 9,
    world: 11,
    channel: 12,
    notice_alert: 13,
    notice_alert2: 14,
    item_enchant: 15,
    super: 16,
    notice_alert3: 17,
    guild_notice: 18,
    guild_notice_noprefix: 19,
    unknown_purple: 20
  ]

  def from_name(name) do
    Keyword.get(@types, name)
  end

  def type_from_int(type_id) do
    @types
    |> Enum.find(fn {_k, v} -> v == type_id end)
    |> elem(0)
  end
end
