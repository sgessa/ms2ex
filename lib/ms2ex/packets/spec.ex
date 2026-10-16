defmodule Ms2ex.Packets.Spec do
  @moduledoc """
  Field-layout contract for `Ms2ex.Packets.Decoder`, the test/debug packet
  decoder in `dev/support`.

  A packet module that adopts this behaviour declares how each of its
  commands is decoded, so debugging tools can turn raw bytes into a plain
  map of field values instead of hand-walking hex.

  Callbacks:

    * `c:spec/1` — the field layout for a command, as a keyword list of
      `{name, type}` entries consumed by `Ms2ex.Packets.PacketReader`
      (`:int`, `:ustring`, `:coord`, ...). `nil` is the command for packets
      that carry no command byte. Names starting with `_` are decoded but
      omitted from the result.
    * `c:commands/0` — maps each command's atom name to its byte value, in
      the same shape the builder uses for its `@commands` table.
  """

  @callback commands :: %{optional(atom()) => integer()}
  @callback spec(command :: integer() | nil) :: keyword()

  @optional_callbacks [commands: 0]
end
