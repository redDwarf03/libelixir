defmodule ArchethicClient.TransactionData.Ledger.UCOLedgerTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.TransactionData.Ledger.UCOLedger
  alias ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer
  alias ArchethicClient.Crypto
  alias ArchethicClient.Utils.VarInt

  describe "struct and instantiation" do
    test "can be created with default empty transfers" do
      uco_ledger = %UCOLedger{}
      assert uco_ledger.transfers == []
    end

    test "can be created with a list of transfers" do
      transfer1 = %Transfer{
        to: Crypto.derive_address("seed_uco_transfer1", 0),
        amount: 1000
      }
      transfer2 = %Transfer{
        to: Crypto.derive_address("seed_uco_transfer2", 0),
        amount: 2000
      }
      uco_ledger = %UCOLedger{transfers: [transfer1, transfer2]}
      assert uco_ledger.transfers == [transfer1, transfer2]
    end
  end

  describe "to_map/1" do
    test "converts a UCOLedger struct to the expected map format" do
      transfer = %Transfer{
        to: Crypto.derive_address("seed_uco_map_to", 0),
        amount: 1500
      }
      uco_ledger = %UCOLedger{transfers: [transfer]}

      expected_map = %{transfers: [Transfer.to_map(transfer)]}
      assert UCOLedger.to_map(uco_ledger) == expected_map
    end

    test "converts with empty transfers list" do
      uco_ledger = %UCOLedger{transfers: []}
      expected_map = %{transfers: []}
      assert UCOLedger.to_map(uco_ledger) == expected_map
    end
  end

  describe "serialize/1" do
    test "correctly serializes a UCOLedger struct with transfers" do
      transfer1_to = Crypto.derive_address("seed_uco_serialize1", 0)
      transfer1_amount = 500
      transfer1 = %Transfer{to: transfer1_to, amount: transfer1_amount}

      transfer2_to = Crypto.derive_address("seed_uco_serialize2", 0)
      transfer2_amount = 750
      transfer2 = %Transfer{to: transfer2_to, amount: transfer2_amount}

      uco_ledger = %UCOLedger{transfers: [transfer1, transfer2]}

      serialized_transfer1 = Transfer.serialize(transfer1)
      serialized_transfer2 = Transfer.serialize(transfer2)
      transfers_bin = <<serialized_transfer1::binary, serialized_transfer2::binary>>
      count_bin = VarInt.from_value(2)

      expected_serialization = <<count_bin::binary, transfers_bin::binary>>
      assert UCOLedger.serialize(uco_ledger) == expected_serialization
    end

    test "correctly serializes with empty transfers list" do
      uco_ledger = %UCOLedger{transfers: []}
      count_bin = VarInt.from_value(0) # Should be <<1,0>> as 0 takes 1 byte to store length, value is 0.
                                        # VarInt.from_value(0) is <<1,0>>
      transfers_bin = <<>>

      expected_serialization = <<count_bin::binary, transfers_bin::binary>>
      assert UCOLedger.serialize(uco_ledger) == expected_serialization
      assert expected_serialization == <<1, 0>> # VarInt for 0 is <<1,0>> (length 1, value 0)
    end
  end
end
