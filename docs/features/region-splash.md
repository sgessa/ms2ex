# Region & splash attacks

Status: partial. `ImmediateActive` / `Delay` are projected by the ingest,
but the server still uses a fixed radius instead of the exact skill geometry
and always lands the first hit immediately. Cube-magic-path placement also
has parity work left: rotated `fire_offset` is applied, but source-height
alignment and `ignore_adjust` snapping are not.
