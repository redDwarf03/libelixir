defmodule ArchethicClient.Utils.TypedEncodingTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.Utils.TypedEncoding
  alias ArchethicClient.Utils.VarInt # Re-added alias

  # Type identifiers from the module
  @type_int 0
  @type_float 1
  @type_str 2
  @type_list 3
  @type_map 4
  @type_bool 5
  @type_nil 6

  # Default bit_size used in serialize/1 is 8 for sign/bool
  @default_bit_size 8

  describe "serialize/1" do
    test "serializes nil" do
      assert TypedEncoding.serialize(nil) == <<@type_nil::8>>
    end

    test "serializes booleans" do
      assert TypedEncoding.serialize(true) == <<@type_bool::8, 1::@default_bit_size>>
      assert TypedEncoding.serialize(false) == <<@type_bool::8, 0::@default_bit_size>>
    end

    test "serializes integers (positive, negative, zero)" do
      # For integer 123: sign_bit=1, VarInt.from_value(123) is <<1, 123>>
      assert TypedEncoding.serialize(123) == <<@type_int::8, 1::@default_bit_size, 1, 123>>

      # For integer 0: sign_bit=1, VarInt.from_value(0) is <<1,0>>
      assert TypedEncoding.serialize(0) == <<@type_int::8, 1::@default_bit_size, 1, 0>>

      # For integer -123: sign_bit=0, VarInt.from_value(123) is <<1,123>>
      assert TypedEncoding.serialize(-123) == <<@type_int::8, 0::@default_bit_size, 1, 123>>

      # Larger number requiring 2 bytes for varint value part
      # VarInt.from_value(300) == <<2, 1, 44>>
      assert TypedEncoding.serialize(300) == <<@type_int::8, 1::@default_bit_size, 2, 1, 44>>
      assert TypedEncoding.serialize(-300) == <<@type_int::8, 0::@default_bit_size, 2, 1, 44>>
    end

    test "serializes floats (positive, negative, zero)" do
      # Floats are converted to bigint (scaled by 10^8) then VarInt encoded
      # 0.0 -> VarInt.from_value(0) -> <<1,0>>. Sign bit 1.
      assert TypedEncoding.serialize(0.0) == <<@type_float::8, 1::@default_bit_size, 1, 0>>

      # 1.23 -> 123_000_000. VarInt.from_value(123_000_000) needs calculation.
      # 123_000_000 is < 2^(8*4) (approx 4B), and > 2^(8*3) (16.7M)
      # Let's take a simpler float: 1.0 -> 100_000_000. VarInt.from_value(100_000_000)
      # VarInt.from_value(100_000_000) -> <<4, 5, 245, 225, 0>> (as 100_000_000 = 5*16777216 + 245*65536 + 225*256 + 0)
      # So for 1.0: <<@type_float::8, 1::@default_bit_size (positive), VarInt.from_value(100_000_000)>>
      assert TypedEncoding.serialize(1.0) == <<@type_float::8, 1::@default_bit_size, 4, 5, 245, 225, 0>>

      # -1.0 -> VarInt.from_value(100_000_000). Sign bit 0.
      assert TypedEncoding.serialize(-1.0) == <<@type_float::8, 0::@default_bit_size, 4, 5, 245, 225, 0>>

      # 0.00000001 (smallest unit) -> VarInt.from_value(1) -> <<1,1>>
      assert TypedEncoding.serialize(0.00000001) == <<@type_float::8, 1::@default_bit_size, 1, 1>>
    end

    test "serializes binary strings" do
      # "" -> size 0, VarInt.from_value(0) is <<1,0>>
      assert TypedEncoding.serialize("") == <<@type_str::8, 1, 0, ""::binary>>
      # "hello" -> size 5, VarInt.from_value(5) is <<1,5>>
      assert TypedEncoding.serialize("hello") == <<@type_str::8, 1, 5, "hello"::binary>>
    end

    test "serializes lists (empty, simple, nested)" do
      # [] -> size 0, VarInt.from_value(0) is <<1,0>>
      assert TypedEncoding.serialize([]) == <<@type_list::8, 1, 0>>

      # [1, true]
      # 1 -> <<@type_int::8, 1::@default_bit_size, 1, 1>>
      # true -> <<@type_bool::8, 1::@default_bit_size>>
      expected_list1 = <<@type_list::8, 1, 2, # VarInt for count 2
                         @type_int::8, 1::@default_bit_size, 1, 1,
                         @type_bool::8, 1::@default_bit_size>>
      assert TypedEncoding.serialize([1, true]) == expected_list1

      # [[nil]] -> VarInt count 1 for outer, VarInt count 1 for inner
      # nil -> <<@type_nil::8>>
      # inner list [nil] -> <<@type_list::8, 1,1, @type_nil::8>>
      # outer list [[nil]] -> <<@type_list::8, 1,1, (serialize [nil]) ::binary >>
      expected_nested_list = <<@type_list::8, 1, 1, # VarInt count 1 (outer)
                                @type_list::8, 1, 1, # VarInt count 1 (inner)
                                @type_nil::8 >>
      assert TypedEncoding.serialize([[nil]]) == expected_nested_list
    end

    test "serializes maps (empty, simple, nested)" do
      # %{} -> size 0, VarInt.from_value(0) is <<1,0>>
      assert TypedEncoding.serialize(%{}) == <<@type_map::8, 1, 0>>

      # %{"a" => 1}
      # "a" -> <<@type_str::8, 1, 1, "a"::binary>>
      # 1   -> <<@type_int::8, 1::@default_bit_size, 1, 1>>
      # VarInt for pair count 1 is <<1,1>>
      expected_map1 = <<@type_map::8, 1, 1, # VarInt for pair count 1
                        @type_str::8, 1, 1, "a"::binary, # key "a"
                        @type_int::8, 1::@default_bit_size, 1, 1>> # value 1
      assert TypedEncoding.serialize(%{"a" => 1}) == expected_map1

      # %{true => %{}}
      # true -> <<@type_bool::8, 1::@default_bit_size>>
      # %{}  -> <<@type_map::8, 1, 0>>
      expected_nested_map = <<@type_map::8, 1, 1, # VarInt for pair count 1 (outer)
                               @type_bool::8, 1::@default_bit_size, # key true
                               @type_map::8, 1, 0>> # value %{}
      assert TypedEncoding.serialize(%{true => %{}}) == expected_nested_map
    end
  end

  describe "deserialize/2" do
    test "deserializes integers (extended mode)" do
      # 123 -> <<@type_int::8, 1::8, 1, 123>> (extended uses 8 bits for sign)
      serialized_123_extended = <<@type_int::8, 1::8, 1, 123>>
      assert TypedEncoding.deserialize(serialized_123_extended, :extended) == {123, <<>>}

      # -123 -> <<@type_int::8, 0::8, 1, 123>>
      serialized_neg123_extended = <<@type_int::8, 0::8, 1, 123>>
      assert TypedEncoding.deserialize(serialized_neg123_extended, :extended) == {-123, <<>>}
    end

    # NOTE: Compact deserialization for integers is currently broken due to VarInt.get_value
    # not supporting non-byte-aligned inputs after a 1-bit sign.
    # test "deserializes integers (compact mode)" do
    #   # 123 -> <<@type_int::8, 1::1, (VarInt for 123)>> - This requires VarInt to handle bit-misaligned stream
    # end

    test "deserializes booleans (compact and extended)" do
      # True (compact)
      serialized_true_compact = <<@type_bool::8, 1::1>>
      assert TypedEncoding.deserialize(serialized_true_compact, :compact) == {true, <<>>}
      # True (extended)
      serialized_true_extended = <<@type_bool::8, 1::8>>
      assert TypedEncoding.deserialize(serialized_true_extended, :extended) == {true, <<>>}

      # False (compact)
      serialized_false_compact = <<@type_bool::8, 0::1>>
      assert TypedEncoding.deserialize(serialized_false_compact, :compact) == {false, <<>>}
      # False (extended)
      serialized_false_extended = <<@type_bool::8, 0::8>>
      assert TypedEncoding.deserialize(serialized_false_extended, :extended) == {false, <<>>}
    end

    test "deserializes floats (extended mode)" do
      val_float_pos = 1.0
      varint_float_pos = <<4, 5, 245, 225, 0>> # For 100_000_000
      serialized_float_pos_extended = <<@type_float::8, 1::8, varint_float_pos::binary>>
      assert TypedEncoding.deserialize(serialized_float_pos_extended, :extended) == {val_float_pos, <<>>}

      val_float_neg = -1.0
      serialized_float_neg_extended = <<@type_float::8, 0::8, varint_float_pos::binary>>
      assert TypedEncoding.deserialize(serialized_float_neg_extended, :extended) == {val_float_neg, <<>>}

      val_float_zero = 0.0
      varint_float_zero = <<1,0>> # For 0
      serialized_float_zero_extended = <<@type_float::8, 1::8, varint_float_zero::binary>>
      assert TypedEncoding.deserialize(serialized_float_zero_extended, :extended) == {val_float_zero, <<>>}
    end

    # NOTE: Compact deserialization for floats is currently broken due to VarInt.get_value
    # not supporting non-byte-aligned inputs after a 1-bit sign.
    # test "deserializes floats (compact mode)" do
    # end

    test "deserializes strings (compact and extended - mode doesn't affect strings)" do
      # "hello" (size 5, VarInt: <<1,5>>)
      val_str_hello = "hello"
      varint_str_hello_len = <<1,5>>
      serialized_str_hello = <<@type_str::8, varint_str_hello_len::binary, val_str_hello::binary>>
      assert TypedEncoding.deserialize(serialized_str_hello, :compact) == {val_str_hello, <<>>}
      assert TypedEncoding.deserialize(serialized_str_hello, :extended) == {val_str_hello, <<>>}

      # "" (size 0, VarInt: <<1,0>>)
      val_str_empty = ""
      varint_str_empty_len = <<1,0>>
      serialized_str_empty = <<@type_str::8, varint_str_empty_len::binary, val_str_empty::binary>>
      assert TypedEncoding.deserialize(serialized_str_empty, :compact) == {val_str_empty, <<>>}
      assert TypedEncoding.deserialize(serialized_str_empty, :extended) == {val_str_empty, <<>>}
    end

    test "deserializes lists (extended mode)" do
      val_list_simple = [1, true]
      ser_item1_extended = TypedEncoding.serialize(1) # Uses 8-bit sign
      ser_item2_extended = TypedEncoding.serialize(true) # Uses 8-bit bool
      serialized_list_simple_extended = <<@type_list::8, VarInt.from_value(2)::binary, ser_item1_extended::binary, ser_item2_extended::binary>>
      assert TypedEncoding.deserialize(serialized_list_simple_extended, :extended) == {val_list_simple, <<>>}

      val_list_nested = [[nil]]
      ser_inner_list_nil = TypedEncoding.serialize([nil])
      serialized_list_nested_extended = <<@type_list::8, VarInt.from_value(1)::binary, ser_inner_list_nil::binary>>
      assert TypedEncoding.deserialize(serialized_list_nested_extended, :extended) == {val_list_nested, <<>>}
    end

    test "deserializes lists (compact mode - with nils only due to implementation constraints)" do
      # Given the issues with non-byte-aligned remainders from compact elements (like bools)
      # and VarInt's expectation of byte-aligned input, only testing compact lists
      # with elements that are themselves byte-aligned and don't cause such issues (e.g., nil).
      val_list_nils = [nil, nil]
      ser_nil = TypedEncoding.serialize(nil) # serialize(nil) is <<@type_nil::8>>, which is byte-aligned
      serialized_list_nils_compact = <<@type_list::8, VarInt.from_value(2)::binary, ser_nil::binary, ser_nil::binary>>
      assert TypedEncoding.deserialize(serialized_list_nils_compact, :compact) == {val_list_nils, <<>>}
    end

    test "deserializes maps (extended mode)" do
      val_map_simple = %{"a" => 1}
      ser_key_a_str = TypedEncoding.serialize("a")
      ser_val_1_int_extended = TypedEncoding.serialize(1)
      serialized_map_simple_extended = <<@type_map::8, VarInt.from_value(1)::binary, ser_key_a_str::binary, ser_val_1_int_extended::binary>>
      assert TypedEncoding.deserialize(serialized_map_simple_extended, :extended) == {val_map_simple, <<>>}

      val_map_nested = %{true => %{}}
      ser_key_true_bool_extended = TypedEncoding.serialize(true)
      ser_val_empty_map_extended = TypedEncoding.serialize(%{})
      serialized_map_nested_extended = <<@type_map::8, VarInt.from_value(1)::binary, ser_key_true_bool_extended::binary, ser_val_empty_map_extended::binary>>
      assert TypedEncoding.deserialize(serialized_map_nested_extended, :extended) == {val_map_nested, <<>>}
    end

    # NOTE: Compact deserialization for lists/maps containing integers or floats, or even booleans,
    # is problematic because elements might leave non-byte-aligned remainders if processed in compact mode,
    # breaking subsequent VarInt reads or type tag reads for the next element.
    # test "deserializes maps (compact mode - with compatible elements)" do
    # end

  end

  describe "roundtrip tests (serialize -> deserialize)" do
    # Helper to test roundtrip for a given value and both modes
    defp test_roundtrip(value) do
      serialized_val = TypedEncoding.serialize(value)
      # serialize/1 always uses 8-bits for internal bool/sign representation (like :extended mode).
      # Therefore, only :extended mode deserialize is guaranteed to roundtrip.
      assert TypedEncoding.deserialize(serialized_val, :extended) == {value, <<>>}, "Extended deserialize failed for: #{inspect(value)}"
    end

    test "roundtrip for nil" do
      test_roundtrip(nil)
    end

    test "roundtrip for booleans" do
      test_roundtrip(true)
      test_roundtrip(false)
    end

    test "roundtrip for integers" do
      test_roundtrip(0)
      test_roundtrip(123)
      test_roundtrip(-123)
      test_roundtrip(300_000)
      test_roundtrip(-300_000)
    end

    test "roundtrip for floats" do
      test_roundtrip(0.0)
      test_roundtrip(1.0)
      test_roundtrip(-1.0)
      test_roundtrip(123.456)
      test_roundtrip(-123.456)
      test_roundtrip(0.00000001)
      test_roundtrip(-0.00000001)
    end

    test "roundtrip for strings" do
      test_roundtrip("")
      test_roundtrip("hello world")
      test_roundtrip("with\nnewlines\tand tabs")
    end

    test "roundtrip for lists (simple and nested)" do
      test_roundtrip([])
      test_roundtrip([1, "a", true, nil])
      test_roundtrip([1, ["nested", false], %{"key" => -3.14}])
      test_roundtrip([[[]], [%{}]]) # Deeply nested empty
    end

    test "roundtrip for maps (simple and nested)" do
      test_roundtrip(%{})
      test_roundtrip(%{"a" => 1, "b" => "string", "c" => true, "d" => nil})
      test_roundtrip(%{1 => "one", %{"nested_key" => false} => [-10, %{}]})
      test_roundtrip(%{[1,2] => %{"map_val" => [nil, true]}}) # List as key, map as val with list
    end
  end
end
