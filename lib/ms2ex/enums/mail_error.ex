defmodule Ms2ex.Enums.MailError do
  use Ms2ex.Enum, %{
    none: 0,
    s_mail_error_username: 1,
    s_mail_error_attachcount: 2,
    s_mail_error_cannot_attach_item: 3,
    s_mail_error_sendmail: 12,
    s_mail_error_alreadyread: 16,
    s_mail_error_already_receive: 17,
    s_mail_error_receiveitem_to_inven: 20,
    s_mail_error_receive_expired: 21,
    s_mail_error_attachcount_effect18: 22,
    s_mail_error_ad_expired: 23,
    s_mail_error_createmail: 24,
    s_mail_error_recipient_equal_sender: 25,
    s_err_lack_meso: 26,
    s_mail_error_block_from_me: 27,
    s_mail_error_block_from_other: 28,
    s_mail_error_admin_character: 29,
    s_mail_error_from_admin_to_user: 30,
    s_mail_error_bancheck: 31,
    s_mail_error_admin_block: 32,
    s_anti_addiction_cannot_receive: 33,
    mail_not_found: 44,
    s_mail_error: 255
  }
end
