# `Ms2ex.Helpers.TriggerArgs`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/helpers/trigger_args.ex#L1)

Coercion for trigger-script action and condition arguments. Script
documents arrive with canonical snake_case keys whose values may be
strings or numbers; these helpers normalize them to the types the
runtime works with.

# `bool_arg`

# `float_arg`

Float argument; strings are parsed, integers are widened.

# `int_arg`

Integer argument; strings are parsed, anything else falls back to 0.

# `int_list_arg`

Integer-list argument: single ids, comma lists and inclusive ranges
("5001-5025" expands to every id).

# `rgb_arg`

"r, g, b" color component floats, rounded to bytes.

# `string_list_arg`

Comma-separated string list kept verbatim (box ids may carry a leading "!"
negation, so they cannot go through the int list parser).

# `widget_key`

Normalizes a script's widget type to the atom key the runtime stores
widgets under; unknown types stay strings.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
