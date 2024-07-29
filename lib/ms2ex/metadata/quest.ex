defmodule Ms2ex.Metadata.Quest do
  defstruct [:id, :name, :basic, :require, :accept_reward, :complete_reward, :remote_accept, :remote_complete, :go_to_npc, :go_to_dungeon, :dispatch, :conditions]

  def ids(), do: [:id]
end
