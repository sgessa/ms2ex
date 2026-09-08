defmodule Ms2ex.Types.GuildBuff do
  defstruct [:id, :level, :expiry_time]

  @default_ids [1, 2, 3, 4, 10_001, 10_002, 10_003, 10_004, 10_005]

  def default_buffs do
    Enum.map(@default_ids, &%__MODULE__{id: &1, level: 1, expiry_time: 0})
  end
end
