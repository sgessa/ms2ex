# `Ms2ex.Packets.Ugc`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/packets/game/ugc.ex#L1)

# `activate_banner`

# `load_banners`

Advertising banners placed on the field: rolling images, the slot currently
displayed on each banner and the reservation schedule per banner.

# `profile_picture`

# `put_ugc`

Appends a user generated content descriptor. Items without one still need the
fields written, so `nil` writes an empty descriptor.

# `reserve_banner_slots`

# `set_endpoint`

Tells the client which host to upload user generated content to and where to
fetch it back from.

# `update_banner`

# `update_item`

# `update_layout_blueprint`

# `update_path`

Points the client at the stored file once the upload completed.

# `upload`

Acknowledges an announced upload. The client uses the returned id as the file
name when it posts the payload to the web server.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
