defmodule ArchethicClient.Utils.TypedEncoding do
  @moduledoc """
  Provides functions for serializing and deserializing various Elixir data types
  into a compact, type-prefixed binary format.

  This encoding scheme is used to represent data such as transaction arguments or
  manifest contents in a space-efficient manner. Each serialized piece of data is
  prefixed with a type byte, followed by the data itself in a type-specific format.

  Supported types for serialization/deserialization include:
  - Integers (signed, variable-length encoding using `VarInt`)
  - Floats (converted to scaled integers before VarInt encoding)
  - Strings (binary, prefixed with VarInt encoded length)
  - Lists (prefixed with VarInt encoded count, elements are recursively serialized)
  - Maps (prefixed with VarInt encoded count of key-value pairs, keys and values are recursively serialized)
  - Booleans (single byte for type, followed by a bit for true/false)
  - Nil (single byte for type)
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

  @doc """
  Serializes an Elixir data type into a type-prefixed binary format.

  Uses an 8-bit size for sign/boolean representation by default in the compact format.
  """
  @spec serialize(arg()) :: binary()
  def serialize(data), do: do_serialize(data, 8) # Default bit_size for sign/bool etc.

  # Serializes an integer.
  # Format: <@type_int::8><sign_bit::bit_size><varint_encoded_abs_value::bitstring>
  defp do_serialize(int, bit_size) when is_integer(int) do
    sign_bit = sign_to_bit(int)
    bin = int |> abs() |> VarInt.from_value()

    <<@type_int::8, sign_bit::integer-size(bit_size), bin::bitstring>>
  end

  # Serializes a float.
  # The float is first converted to a scaled integer (multiplied by 10^8) before VarInt encoding.
  # Format: <@type_float::8><sign_bit::bit_size><varint_encoded_abs_scaled_value::bitstring>
  defp do_serialize(float, bit_size) when is_float(float) do
    sign_bit = sign_to_bit(float)
    bin = float |> abs() |> Utils.to_bigint() |> VarInt.from_value() # to_bigint typically scales by 10^8
    <<@type_float::8, sign_bit::integer-size(bit_size), bin::bitstring>>
  end

  # Serializes a binary string.
  # Format: <@type_str::8><varint_encoded_length::binary><string_content::bitstring>
  defp do_serialize(bin, _bit_size) when is_binary(bin) do
    size = byte_size(bin)
    size_bin = VarInt.from_value(size)
    <<@type_str::8, size_bin::binary, bin::bitstring>>
  end

  # Serializes a list.
  # Elements are recursively serialized.
  # Format: <@type_list::8><varint_encoded_count::binary><serialized_element_1>...<serialized_element_N>
  defp do_serialize(list, bit_size) when is_list(list) do
    size = length(list)
    size_bin = VarInt.from_value(size)

    Enum.reduce(list, <<@type_list::8, size_bin::binary>>, fn item, acc ->
      <<acc::bitstring, do_serialize(item, bit_size)::bitstring>>
    end)
  end

  # Serializes a map.
  # Keys and values are recursively serialized in sequence.
  # Format: <@type_map::8><varint_encoded_pair_count::binary><serialized_key_1><serialized_value_1>...<serialized_key_N><serialized_value_N>
  defp do_serialize(map, bit_size) when is_map(map) do
    size = map_size(map)
    size_bin = VarInt.from_value(size)

    Enum.reduce(map, <<@type_map::8, size_bin::binary>>, fn {k, v}, acc ->
      <<acc::bitstring, do_serialize(k, bit_size)::bitstring, do_serialize(v, bit_size)::bitstring>>
    end)
  end

  # Serializes a boolean.
  # Format: <@type_bool::8><bool_value::bit_size> (0 for false, 1 for true)
  defp do_serialize(bool, bit_size) when is_boolean(bool) do
    bool_bit = if bool, do: 1, else: 0
    <<@type_bool::8, bool_bit::integer-size(bit_size)>>
  end

  # Serializes nil.
  # Format: <@type_nil::8>
  defp do_serialize(nil, _bit_size), do: <<@type_nil::8>>

  # Converts a number's sign to a bit (1 for non-negative, 0 for negative).
  defp sign_to_bit(num) when num >= 0, do: 1
  defp sign_to_bit(_num), do: 0

  @doc """
  Deserializes a type-prefixed binary into an Elixir data type.

  The `mode` argument (`:compact` or `:extended`) determines the bit size used
  for interpreting sign bits or boolean values (1 bit for compact, 8 bits for extended).
  """
  @spec deserialize(binary :: bitstring(), mode :: ArchethicClient.Transaction.serialization_mode()) ::
  {arg(), bitstring()}
  def deserialize(bin, :compact), do: do_deserialize(bin, 1)
  def deserialize(bin, :extended), do: do_deserialize(bin, 8)

  # Deserializes an integer.
  # Expects format: <@type_int::8><sign_bit::bit_size><varint_encoded_abs_value::bitstring>
  # Returns {deserialized_integer, rest_of_binary}
  defp do_deserialize(<<@type_int::8, rest::bitstring>>, bit_size) do
    <<sign_bit::integer-size(bit_size), rest_after_sign::bitstring>> = rest
    {int_val, rest_after_varint} = VarInt.get_value(rest_after_sign)
    deserialized_int = int_val * bit_to_sign(sign_bit)
    {deserialized_int, rest_after_varint}
  end

  # Deserializes a float.
  # Expects format: <@type_float::8><sign_bit::bit_size><varint_encoded_abs_scaled_value::bitstring>
  defp do_deserialize(<<@type_float::8, rest::bitstring>>, bit_size) do
    <<sign_bit::integer-size(bit_size), rest_after_sign::bitstring>> = rest
    {scaled_val, rest_after_varint} = VarInt.get_value(rest_after_sign)
    float_val = (scaled_val * bit_to_sign(sign_bit)) / :math.pow(10, 8)
    {float_val, rest_after_varint}
  end

  # Deserializes a binary string.
  # Expects format: <@type_str::8><varint_encoded_length::binary><string_content::bitstring>
  defp do_deserialize(<<@type_str::8, rest::bitstring>>, _bit_size) do
    {size, rest_after_size_varint} = VarInt.get_value(rest)
    <<str_content::binary-size(size), rest_after_string::bitstring>> = rest_after_size_varint
    {str_content, rest_after_string}
  end

  # Deserializes a list.
  # Expects format: <@type_list::8><varint_encoded_count::binary><serialized_element_1>...<serialized_element_N>
  defp do_deserialize(<<@type_list::8, rest::bitstring>>, bit_size) do
    {count, rest_after_count_varint} = VarInt.get_value(rest)
    deserialize_list_elements(rest_after_count_varint, count, bit_size, [])
  end

  # Deserializes a map.
  # Expects format: <@type_map::8><varint_encoded_pair_count::binary><serialized_key_1><serialized_value_1>...<serialized_key_N><serialized_value_N>
  defp do_deserialize(<<@type_map::8, rest::bitstring>>, bit_size) do
    {pair_count, rest_after_count_varint} = VarInt.get_value(rest)
    deserialize_map_pairs(rest_after_count_varint, pair_count, bit_size, [])
  end

  # Deserializes a boolean.
  # Expects format: <@type_bool::8><bool_value::bit_size>
  defp do_deserialize(<<@type_bool::8, rest::bitstring>>, bit_size) do
    <<bool_bit::integer-size(bit_size), rest_after_bool::bitstring>> = rest
    {bool_bit == 1, rest_after_bool}
  end

  # Deserializes nil.
  # Expects format: <@type_nil::8>
  defp do_deserialize(<<@type_nil::8, rest::bitstring>>, _bit_size) do
    {nil, rest}
  end

  # Helper to recursively deserialize list elements
  defp deserialize_list_elements(binary, 0, _bit_size, acc), do: {Enum.reverse(acc), binary}
  defp deserialize_list_elements(binary, count, bit_size, acc) when count > 0 do
    {element, rest} = do_deserialize(binary, bit_size)
    deserialize_list_elements(rest, count - 1, bit_size, [element | acc])
  end

  # Helper to recursively deserialize map key-value pairs
  defp deserialize_map_pairs(binary, 0, _bit_size, acc_pairs), do: {Map.new(Enum.reverse(acc_pairs)), binary}
  defp deserialize_map_pairs(binary, count, bit_size, acc_pairs) when count > 0 do
    {key, rest_after_key} = do_deserialize(binary, bit_size)
    {value, rest_after_value} = do_deserialize(rest_after_key, bit_size)
    deserialize_map_pairs(rest_after_value, count - 1, bit_size, [{key, value} | acc_pairs])
  end

  # Converts a bit back to a sign multiplier (1 for bit 1, -1 for bit 0).
  defp bit_to_sign(0), do: -1
  defp bit_to_sign(1), do: 1
end
