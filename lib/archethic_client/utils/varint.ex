defmodule ArchethicClient.Utils.VarInt do
  @moduledoc """
    Provides functions for encoding integers into a variable-length binary format
    and decoding them back.

    In this VarInt implementation:
    - The first byte of the encoded binary indicates the number of subsequent bytes (`N`)
      that constitute the actual integer value.
    - The integer itself is then stored in those `N` bytes.

    This is useful for compactly representing integers where smaller values use fewer bytes.
  """

  @doc """
  Encodes an integer into a VarInt binary format.

  The function first determines the minimum number of bytes required to store the integer value.
  This count (1-255) is then prepended as a single byte to the actual integer value (stored in N bytes).

  ## Examples
      iex> ArchethicClient.Utils.VarInt.from_value(200)
      <<1, 200>>
      iex> ArchethicClient.Utils.VarInt.from_value(300)
      <<2, 1, 44>> # 300 = 256 * 1 + 44
  """
  @spec from_value(integer()) :: bitstring()
  def from_value(value) do
    bytes = min_bytes_to_store(value)
    <<bytes::8, value::bytes*8>>
  end

  # Calculates the minimum number of bytes required to store the given integer value.
  # It finds the smallest N (from 1 to 255) such that `value < 2^(8*N)`.
  @spec min_bytes_to_store(integer()) :: integer()
  defp min_bytes_to_store(value) do
    # Since values go from
    # 1*8 => 2^8 => 255 ~BYTES=1
    # 2*8 => 16 => 2^16 => 65535 ~BYTES=2
    # 3*8 => 24 => 2^24 => 16777215 ~BYTES=3
    Enum.find(1..255, fn x -> value < Integer.pow(2, 8 * x) end)
  end

  @doc """
  Decodes a VarInt binary back into an integer and the rest of the binary string.

  It reads the first byte to determine how many subsequent bytes (`N`) form the integer.
  Then, it reads those `N` bytes to reconstruct the integer value.

  Returns a tuple `{integer_value, rest_of_binary_string}`.

  ## Examples
      iex> ArchethicClient.Utils.VarInt.get_value(<<1, 200, 99, 98>>)
      {200, <<99, 98>>}
      iex> ArchethicClient.Utils.VarInt.get_value(<<2, 1, 44, 99, 98>>)
      {300, <<99, 98>>}
  """
  @spec get_value(bitstring()) :: {integer(), bitstring()}
  def get_value(data) do
    <<bytes::8, rest::bitstring>> = data
    <<value::bytes*8, rest::bitstring>> = rest

    {
      value,
      rest
    }
  end
end
