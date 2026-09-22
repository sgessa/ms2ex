defmodule Ms2ex.Enums.CharacterDeleteError do
  use Ms2ex.Enum, %{
    ok: 0,
    s_char_err_already_destroy: 1,
    s_char_err_guild_master: 3,
    s_char_err_guild: 4,
    s_char_err_unread_mail: 7,
    s_char_err_no_destroy_wait: 8,
    s_char_err_next_delete_char_date: 10,
    s_char_err_destroy: 255
  }
end
