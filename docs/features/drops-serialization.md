# Drop & field-item serialization

Status: open. The drop packet still has three deviations:

- ~64 ints of trailing zero padding on both clauses (the client sends none)
- mob-drop currency items still use a legacy `count=1` + entry payload
- SP/stamina/merets use the legacy currency blob instead of the full item
  class

See field-add-item.md for the packet layout work already done.
