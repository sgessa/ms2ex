defmodule Ms2ex.Metadata.Items.EquipSlot do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :NONE, 0
  field :HR, 1
  field :FA, 2
  field :FD, 3
  field :LH, 4
  field :RH, 5
  field :CP, 6
  field :MT, 7
  field :CL, 8
  field :PA, 9
  field :GL, 10
  field :SH, 11
  field :FH, 12
  field :EY, 13
  field :EA, 14
  field :PD, 15
  field :RI, 16
  field :BE, 17
  field :ER, 18
  field :OH, 19
end
