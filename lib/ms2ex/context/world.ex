defmodule Ms2ex.World do
  def broadcast(packet) do
    Phoenix.PubSub.broadcast(Ms2ex.PubSub, "world", {:push, packet})
  end

  def subscribe() do
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "world")
  end
end
