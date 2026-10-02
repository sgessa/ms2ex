# `Ms2ex.Managers.Mail`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/mail.ex#L1)

Mail flows: sending, collecting attachments and notifications.

Persistence (mail rows, attachments, read/collected timestamps) lives in
`Ms2ex.Context.Mails`; this module orchestrates the flows around them —
validations, wallet credits, inventory transfers, quest notifications and
the packets the client receives.

# `bulk_collect`

Bulk collects attachments from multiple mails.

# `collect`

Collects attachments (currencies and items) from a mail.

# `notify_recipient`

Pushes an unread mail notification to an online character.

# `send_player_mail`

Sends a player-to-player mail.

# `send_system_mail`

Sends a system mail with optional currency and item attachments.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
