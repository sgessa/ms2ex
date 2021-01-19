defmodule Ms2ex.Crypto.Crypter do
  def get_index(version, index) do
    rem(version + index, 3) + 1
  end
end
