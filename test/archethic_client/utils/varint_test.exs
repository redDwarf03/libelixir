defmodule ArchethicClient.Utils.VarIntTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.Utils.VarInt

  describe "from_value/1" do
    test "encodes 0 correctly" do
      assert VarInt.from_value(0) == <<1, 0>>
    end

    test "encodes a 1-byte value (1)" do
      assert VarInt.from_value(1) == <<1, 1>>
    end

    test "encodes a 1-byte value (255)" do
      assert VarInt.from_value(255) == <<1, 255>>
    end

    test "encodes a 2-byte value (256)" do
      # 256 = 1 * 256 + 0
      assert VarInt.from_value(256) == <<2, 1, 0>>
    end

    test "encodes another 2-byte value (300)" do
      # 300 = 1 * 256 + 44
      assert VarInt.from_value(300) == <<2, 1, 44>>
    end

    test "encodes a 2-byte value (65535)" do
      # 65535 = 255 * 256 + 255
      assert VarInt.from_value(65_535) == <<2, 255, 255>>
    end

    test "encodes a 3-byte value (65536)" do
      # 65536 = 1 * 256^2 + 0 * 256 + 0
      assert VarInt.from_value(65_536) == <<3, 1, 0, 0>>
    end

    test "encodes a larger 3-byte value (16_777_215)" do
      # 16_777_215 = 255 * 256^2 + 255 * 256 + 255
      assert VarInt.from_value(16_777_215) == <<3, 255, 255, 255>>
    end

    test "encodes a 4-byte value (16_777_216)" do
      assert VarInt.from_value(16_777_216) == <<4, 1, 0, 0, 0>>
    end
  end

  describe "get_value/1" do
    test "decodes a 1-byte value (0)" do
      assert VarInt.get_value(<<1, 0>>) == {0, <<>>}
    end

    test "decodes a 1-byte value (200) with remaining binary" do
      assert VarInt.get_value(<<1, 200, 99, 98>>) == {200, <<99, 98>>}
    end

    test "decodes a 2-byte value (300) with remaining binary" do
      assert VarInt.get_value(<<2, 1, 44, 10, 20>>) == {300, <<10, 20>>}
    end

    test "decodes a 3-byte value (65536)" do
      assert VarInt.get_value(<<3, 1, 0, 0>>) == {65_536, <<>>}
    end

    test "decodes a 4-byte value (16_777_216) with remaining binary" do
      assert VarInt.get_value(<<4, 1, 0, 0, 0, 1, 2, 3>>) == {16_777_216, <<1, 2, 3>>}
    end
  end

  describe "roundtrip (from_value |> get_value)" do
    test "correctly encodes and decodes 0" do
      value = 0
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end

    test "correctly encodes and decodes 127" do
      value = 127
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end

    test "correctly encodes and decodes 255" do
      value = 255
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end

    test "correctly encodes and decodes 256" do
      value = 256
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end

    test "correctly encodes and decodes 10_000" do
      value = 10_000
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end

    test "correctly encodes and decodes 65_535" do
      value = 65_535
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end

    test "correctly encodes and decodes 65_536" do
      value = 65_536
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end

    test "correctly encodes and decodes a large number (e.g. 2_000_000_000)" do
      # This will require 4 bytes: 2_000_000_000 is less than 2^(8*4)
      value = 2_000_000_000
      assert VarInt.get_value(VarInt.from_value(value)) == {value, <<>>}
    end
  end
end
