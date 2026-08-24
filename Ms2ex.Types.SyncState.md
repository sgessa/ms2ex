# `Ms2ex.Types.SyncState`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/types/sync_state.ex#L1)

Schema and functions for managing and synchronizing game state between clients.
Provides functionality to serialize and deserialize sync state to and from packets.

# `from_packet`

Deserializes a sync state from a packet.

Reads all the necessary state information from the given packet and returns
a tuple with the created sync state and the remaining packet data.

## Returns
  - {sync_state, packet}: A tuple with the deserialized sync state and the remaining packet data

# `has_bit?`

# `put_state`

Serializes a sync state to a packet.

Main entry point for writing state data to a packet. This function orchestrates
the writing of all components of the sync state by delegating to specialized helper functions.

## Parameters
  - packet: The packet to write to
  - state: The sync state to serialize

## Returns
  - packet: The updated packet containing the serialized state

---

*Consult [api-reference.md](api-reference.md) for complete listing*
