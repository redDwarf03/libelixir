defmodule ArchethicClient.Utils.TypedEncoding do
  @moduledoc """
  Handle encoding of typed data
  """

  alias ArchethicClient.Utils
  alias ArchethicClient.Utils.VarInt

  @type_int 0
  @type_float 1
  @type_str 2
  @type_list 3
  @type_map 4
  @type_bool 5
  @type_nil 6

  @type arg() :: number() | boolean() | binary() | list() | map() | nil

  @spec serialize(arg()) :: binary()
  def serialize(data), do: do_serialize(data, 8)

  defp do_serialize(int, bit_size) when is_integer(int) do
    sign_bit = sign_to_bit(int)
    bin = int |> abs() |> VarInt.from_value()

    <<@type_int::8, sign_bit::integer-size(bit_size), bin::bitstring>>
  end

  defp do_serialize(float, bit_size) when is_float(float) do
    sign_bit = sign_to_bit(float)
    bin = float |> abs() |> Utils.to_bigint() |> VarInt.from_value()
    <<@type_float::8, sign_bit::integer-size(bit_size), bin::bitstring>>
  end

  defp do_serialize(bin, _bit_size) when is_binary(bin) do
    size = byte_size(bin)
    size_bin = VarInt.from_value(size)
    <<@type_str::8, size_bin::binary, bin::bitstring>>
  end

  defp do_serialize(list, bit_size) when is_list(list) do
    size = length(list)
    size_bin = VarInt.from_value(size)

    Enum.reduce(list, <<@type_list::8, size_bin::binary>>, fn item, acc ->
      <<acc::bitstring, do_serialize(item, bit_size)::bitstring>>
    end)
  end

  defp do_serialize(map, bit_size) when is_map(map) do
    size = map_size(map)
    size_bin = VarInt.from_value(size)

    Enum.reduce(map, <<@type_map::8, size_bin::binary>>, fn {k, v}, acc ->
      <<acc::bitstring, do_serialize(k, bit_size)::bitstring, do_serialize(v, bit_size)::bitstring>>
    end)
  end

  defp do_serialize(bool, bit_size) when is_boolean(bool) do
    bool_bit = if bool, do: 1, else: 0
    <<@type_bool::8, bool_bit::integer-size(bit_size)>>
  end

  defp do_serialize(nil, _bit_size), do: <<@type_nil::8>>

  defp sign_to_bit(num) when num >= 0, do: 1
  defp sign_to_bit(_num), do: 0

  @spec deserialize(binary :: bitstring(), mode :: Transaction.serialization_mode()) ::
  {arg(), bitstring()}
  def deserialize(bin, :compact), do: do_deserialize(bin, 1)
  def deserialize(bin, :extended), do: do_deserialize(bin, 8)


  defp do_deserialize(<<@type_int::8, rest::bitstring>>, bit_size) do
    <<sign_bit::integer-size(bit_size), rest::bitstring>> = rest
    {int, rest} = VarInt.get_value(rest)
    int = int * bit_to_sign(sign_bit)
    {int, rest}
  end

  defp bit_to_sign(0), do: -1
  defp bit_to_sign(1), do: 1
end
