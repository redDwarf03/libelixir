defmodule ArchethicClient.Crypto.Ed25519 do
  @moduledoc false

  import Bitwise

  @p 57_896_044_618_658_097_711_785_492_504_343_953_926_634_992_332_820_282_019_728_792_003_956_564_819_949
  @d -4_513_249_062_541_557_337_682_894_930_092_624_173_785_641_285_191_125_241_628_941_591_882_900_924_598_840_740
  @i 19_681_161_376_707_505_956_807_079_304_988_542_015_446_066_515_923_890_162_744_021_073_123_829_784_752

  @doc """
  Generate an Ed25519 key pair
  """
  @spec generate_keypair(binary()) :: {binary(), binary()}
  def generate_keypair(seed) when is_binary(seed) and byte_size(seed) < 32 do
    seed = :crypto.hash(:sha256, seed)
    do_generate_keypair(seed)
  end

  def generate_keypair(seed) when is_binary(seed) and byte_size(seed) > 32,
    do: do_generate_keypair(:binary.part(seed, 0, 32))

  def generate_keypair(seed) when is_binary(seed), do: do_generate_keypair(seed)

  defp do_generate_keypair(seed), do: :crypto.generate_key(:eddsa, :ed25519, seed)

  @doc """
  Sign a message with the given Ed25519 private key
  """
  @spec sign(binary(), iodata()) :: binary()
  def sign(<<private_key::binary-32>> = _key, data) when is_binary(data) or is_list(data),
    do: :crypto.sign(:eddsa, :sha512, data, [private_key, :ed25519])

  @doc """
  Verify if a given Ed25519 public key matches the signature among with its data
  """
  @spec verify?(binary(), binary(), binary()) :: boolean()
  def verify?(<<public_key::binary-32>>, data, sig) when (is_binary(data) or is_list(data)) and is_binary(sig),
    do: :crypto.verify(:eddsa, :sha512, data, sig, [public_key, :ed25519])

  @spec convert_to_x25519_private_key(ed25519_seed :: binary()) :: binary()
  def convert_to_x25519_private_key(ed25519_seed) when byte_size(ed25519_seed) == 32 do
    # ed25519_seed is the 32-byte private seed key for Ed25519.
    # The X25519 private key is derived from the first 32 bytes of SHA512(ed25519_seed),
    # interpreted as a little-endian integer, then clamped, and encoded back to
    # a 32-byte little-endian binary.
    hashed_seed = :crypto.hash(:sha512, ed25519_seed) # 64-byte binary

    # Extract the first 32 bytes and interpret as a little-endian integer.
    <<scalar_to_clamp::little-integer-size(256), _rest_of_hash::binary-size(32)>> = hashed_seed

    clamped_scalar_integer = clamp(scalar_to_clamp)

    # Encode the clamped integer back to a 32-byte little-endian binary.
    <<clamped_scalar_integer::little-integer-size(256)>>
  end

  @spec convert_to_x25519_public_key(ed25519_public_key :: binary()) :: binary()
  def convert_to_x25519_public_key(ed25519_public_key) do
    {_, y} = decodepoint(ed25519_public_key)
    u = mod((1 + y) * inv(1 - y), @p)
    <<u::little-size(256)>>
  end

  defp clamp(c), do: c |> band(~~~7) |> band(~~~(128 <<< (8 * 31))) |> bor(64 <<< (8 * 31))

  defp decodepoint(<<n::little-size(256)>>) do
    xc = bsr(n, 255)
    y = band(n, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    x = xrecover(y)

    point =
      case x &&& 1 do
        ^xc -> {x, y}
        _ -> {@p - x, y}
      end

    if isoncurve(point), do: point, else: raise("Point off Edwards curve")
  end

  defp decodepoint(_), do: raise("Provided value not a key")

  defp xrecover(y) do
    xx = (y * y - 1) * inv(@d * y * y + 1)
    x = expmod(xx, div(@p + 3, 8), @p)

    x =
      case mod(x * x - xx, @p) do
        0 -> x
        _ -> mod(x * @i, @p)
      end

    case mod(x, 2) do
      0 -> @p - x
      _ -> x
    end
  end

  defp mod(x, _y) when x == 0, do: 0
  defp mod(x, y) when x > 0, do: rem(x, y)
  defp mod(x, y) when x < 0, do: rem(y + rem(x, y), y)

  defp inv(x), do: expmod(x, @p - 2, @p)

  defp expmod(b, e, m) when b > 0, do: b |> :crypto.mod_pow(e, m) |> :binary.decode_unsigned()

  defp expmod(b, e, m) do
    i = b |> abs() |> :crypto.mod_pow(e, m) |> :binary.decode_unsigned()

    cond do
      mod(e, 2) == 0 -> i
      i == 0 -> i
      true -> m - i
    end
  end

  defp isoncurve({x, y}), do: mod(-x * x + y * y - 1 - @d * x * x * y * y, @p) == 0
end
