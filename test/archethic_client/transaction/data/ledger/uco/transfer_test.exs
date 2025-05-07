defmodule ArchethicClient.TransactionData.Ledger.UCOLedger.TransferTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer
  alias ArchethicClient.Crypto

  describe "struct and instantiation" do
    test "can be created with valid fields" do
      to_address = Crypto.derive_address("seed_uco_to", 0)
      amount = 123_456_789
      transfer = %Transfer{to: to_address, amount: amount}

      assert transfer.to == to_address
      assert transfer.amount == amount
    end
  end

  describe "to_map/1" do
    test "converts a Transfer struct to the expected map format" do
      to_address = Crypto.derive_address("seed_uco_map", 0)
      amount = 987_654_321
      transfer = %Transfer{to: to_address, amount: amount}

      expected_map = %{
        to: Base.encode16(to_address),
        amount: amount
      }
      assert Transfer.to_map(transfer) == expected_map
    end
  end

  describe "serialize/1" do
    test "correctly serializes a Transfer struct" do
      to_address = Crypto.derive_address("seed_uco_serialize", 0)
      amount = 1_000_000_000 # Example: 10 UCO
      transfer = %Transfer{to: to_address, amount: amount}

      expected_serialization = <<to_address::binary, amount::unsigned-integer-size(64)>>
      # Using unsigned-integer-size explicitly to match common binary patterns for amounts.
      # The implementation uses `amount::64` which should be equivalent for positive integers.

      assert Transfer.serialize(transfer) == expected_serialization
    end

    test "correctly serializes with zero amount" do
      to_address = Crypto.derive_address("seed_uco_serialize_zero", 0)
      amount = 0
      transfer = %Transfer{to: to_address, amount: amount}

      expected_serialization = <<to_address::binary, amount::unsigned-integer-size(64)>>
      assert Transfer.serialize(transfer) == expected_serialization
    end
  end
end
