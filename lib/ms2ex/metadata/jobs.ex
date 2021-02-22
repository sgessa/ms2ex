defmodule Ms2ex.Metadata.Job do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :unknown, 1
  field :knight, 10
  field :berseker, 20
  field :wizard, 30
  field :priest, 40
  field :archer, 50
  field :heavy_gunner, 60
  field :thief, 70
  field :assassin, 80
  field :rune_blade, 90
  field :striker, 100
  field :soul_binder, 110
  field :game_master, 999
end
