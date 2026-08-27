defmodule Ms2ex.Packets.LoadCubes do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    load: 0x0,
    plot_state: 0x1,
    load_plots: 0x2,
    plot_expiry: 0x3
  }

  # an empty field: no cubes, a single free plot (number 0) and no expiry
  def load do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_bool(false)
    |> put_int(0)
  end

  def plot_state do
    __MODULE__
    |> build()
    |> put_byte(@modes.plot_state)
    |> put_int(1)
    |> put_int(0)
    |> put_bool(false)
  end

  def load_plots do
    __MODULE__
    |> build()
    |> put_byte(@modes.load_plots)
    |> put_int(0)
  end

  def plot_expiry do
    __MODULE__
    |> build()
    |> put_byte(@modes.plot_expiry)
    |> put_int(0)
  end
end
