defmodule ArchethicClient.UtilsTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.Utils
  # import Decimal # Unused import

  describe "to_bigint/2" do
    test "converts integer correctly with default decimals (8)" do
      assert Utils.to_bigint(123) == 123 * 100_000_000
    end

    test "converts integer correctly with specified decimals (2)" do
      assert Utils.to_bigint(123, 2) == 123 * 100
    end

    test "converts float correctly with default decimals (8)" do
      assert Utils.to_bigint(1.2345) == 123_450_000
      assert Utils.to_bigint(0.00000001) == 1
      # Corrected expected value
      assert Utils.to_bigint(123.0) == 12_300_000_000
    end

    test "converts float correctly with specified decimals (2)" do
      # Uses floor rounding
      assert Utils.to_bigint(1.2345, 2) == 123
      assert Utils.to_bigint(1.99, 2) == 199
    end

    test "converts string correctly with default decimals (8)" do
      assert Utils.to_bigint("1.2345") == 123_450_000
      # Corrected expected value
      assert Utils.to_bigint("123") == 12_300_000_000
    end

    test "converts string correctly with specified decimals (2)" do
      assert Utils.to_bigint("1.2345", 2) == 123
      assert Utils.to_bigint("123", 2) == 12_300
    end

    test "converts Decimal correctly with default decimals (8)" do
      assert Utils.to_bigint(Decimal.new("1.2345")) == 123_450_000
    end

    test "converts Decimal correctly with specified decimals (2)" do
      assert Utils.to_bigint(Decimal.new("1.2345"), 2) == 123
    end

    test "handles zero correctly" do
      assert Utils.to_bigint(0) == 0
      assert Utils.to_bigint(0.0) == 0
      assert Utils.to_bigint("0") == 0
      assert Utils.to_bigint(Decimal.new(0)) == 0
    end
  end

  describe "from_bigint/2" do
    test "converts integer correctly with default decimals (8)" do
      assert Utils.from_bigint(123_450_000) == "1.2345"
      assert Utils.from_bigint(1) == "0.00000001"
      assert Utils.from_bigint(12_300_000_000) == "123"
      assert Utils.from_bigint(100_000_000) == "1"
    end

    test "converts integer correctly with specified decimals (2)" do
      assert Utils.from_bigint(123, 2) == "1.23"
      assert Utils.from_bigint(1, 2) == "0.01"
      assert Utils.from_bigint(12_300, 2) == "123"
    end

    test "handles zero correctly" do
      assert Utils.from_bigint(0) == "0"
      assert Utils.from_bigint(0, 2) == "0"
    end

    test "handles large integer correctly with specified decimals (10)" do
      assert Utils.from_bigint(123_456_789_012, 10) == "12.3456789012"
    end
  end

  describe "wrap_binary/1" do
    test "returns binary as is if already a binary" do
      binary_input = <<1, 2, 3, 4>>
      assert Utils.wrap_binary(binary_input) === binary_input
    end

    test "pads non-byte-aligned bitstring with zeros" do
      # 3 bits, needs 5 padding bits
      bitstring_input = <<0b101::size(3)>>
      # <<5::3, 0::5>> which is <<0xA0>>
      expected_output = <<0b10100000::size(8)>>
      assert Utils.wrap_binary(bitstring_input) == expected_output
    end

    test "returns byte-aligned bitstring as is" do
      bitstring_input = <<0b10101010::size(8)>>
      assert Utils.wrap_binary(bitstring_input) == bitstring_input
    end

    test "handles empty bitstring" do
      bitstring_input = <<>>
      # Empty binary is still binary
      assert Utils.wrap_binary(bitstring_input) == bitstring_input
    end

    test "handles bitstring that is exactly 8 bits" do
      # This is already a binary
      bitstring_input = <<1, 2, 3, 4, 5, 6, 7, 8>>
      assert Utils.wrap_binary(bitstring_input) == bitstring_input
    end
  end

  describe "wrap_binary/2 (list processing)" do
    test "processes a flat list of binaries and bitstrings" do
      list_input = [<<1, 2>>, <<0b110::3>>, "hello"]
      # <<1,2>> -> <<1,2>>
      # <<0b110::3>> -> <<0b11000000>> (<<0xC0>>)
      # "hello" -> "hello"
      expected_output = <<1, 2, 0b11000000::8, "hello"::binary>>
      assert Utils.wrap_binary(list_input) == expected_output
      # Explicit empty acc
      assert Utils.wrap_binary(list_input, []) == expected_output
    end

    test "processes a nested list of binaries and bitstrings" do
      list_input = [<<1>>, [<<0b10::2>>, "AB"], "C"]
      # <<1>> -> <<1>>
      # [<<0b10::2>>, "AB"]
      #   <<0b10::2>> -> <<0b10000000>> (<<0x80>>)
      #   "AB" -> "AB"
      #   inner becomes <<0x80, "AB">>
      # "C" -> "C"
      expected_output = <<1, 0b10000000::8, "AB"::binary, "C"::binary>>
      assert Utils.wrap_binary(list_input) == expected_output
    end

    test "handles an empty list" do
      assert Utils.wrap_binary([]) == <<>>
    end

    test "handles a list with only an empty list" do
      assert Utils.wrap_binary([[]]) == <<>>
    end

    test "handles deeply nested empty lists" do
      assert Utils.wrap_binary([[[]], []]) == <<>>
    end

    test "handles list with mixed empty and non-empty elements" do
      list_input = [[<<1::1>>], [], ["a", <<2::2>>]]
      # [[<<1::1>>]] -> <<0b10000000>>
      # [] -> effectively nothing added to iolist before final join
      # ["a", <<2::2>>] -> ["a", <<0b10000000>>]
      # -> <<0b10000000, "a", 0b10000000>>
      expected = <<0b10000000::8, "a"::binary, 0b10000000::8>>
      assert Utils.wrap_binary(list_input) == expected
    end
  end

  # Note: wrap_binary/1 and wrap_binary/2 are covered by doctests.
end
