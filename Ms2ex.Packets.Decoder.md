# `Ms2ex.Packets.Decoder`
[🔗](https://github.com/sgessa/ms2ex/blob/main/dev/support/packet_decoder.ex#L1)

Test/debug helper that decodes a built packet into a plain map of field
values, instead of hand-walking hex bytes with `PacketReader`.

Works for both server-built packets (layout from the builder module) and
client-sent packets (layout from the handler module). In both cases the
module adopts `Ms2ex.Packets.Spec` (see the behaviour for the layout
format). Packets that carry a command byte also expose
`c:Ms2ex.Packets.Spec.commands/0`, which the decoder uses to resolve the
command's atom name.

Usage in tests or iex:

    Ms2ex.Packets.Decoder.decode(:send, bytes)
    #=> %{opcode: 38, direction: :send, name: "ADD_PORTAL", command: :add,
    #    fields: %{id: 2, ...}, rest: ""}

    Ms2ex.Packets.Decoder.decode_hex(:recv, "11 00 00 00 00 00 05 ...")

# `decode`

Decodes packet bytes of the given direction (`:send` for server-built
packets, `:recv` for client-sent ones). The direction determines which
opcode table and which module type provides the layout, so both sides of
a shared opcode resolve unambiguously.

# `decode_hex`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
