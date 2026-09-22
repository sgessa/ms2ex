defmodule Ms2ex.Crypto.Native do
  @moduledoc false
  # Bindings to the native packet-crypto NIF: builds the crypter sequence for
  # a protocol version/block IV pair and applies it to packet payloads.

  use Rustler,
    otp_app: :ms2ex,
    crate: :crypto

  @typedoc "Opaque native crypter: `:rearrange`, `{:xor, byte(), byte()}` or `{:table, binary(), binary()}`"
  @type crypter :: :rearrange | {:xor, byte(), byte()} | {:table, binary(), binary()}
  @type crypt_seq :: [crypter()]

  @spec crypt_seq(non_neg_integer(), non_neg_integer()) :: crypt_seq()
  def crypt_seq(_version, _block_iv), do: nif_error()

  @spec transform(crypt_seq(), binary(), boolean()) :: binary()
  def transform(_crypt_seq, _data, _encrypt), do: nif_error()

  @spec crt_rand(non_neg_integer()) :: non_neg_integer()
  def crt_rand(_seed), do: nif_error()

  defp nif_error do
    :erlang.nif_error("the native crypto library is not loaded — compile it with `mix compile`")
  end
end
