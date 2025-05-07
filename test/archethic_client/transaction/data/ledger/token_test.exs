defmodule ArchethicClient.TransactionData.Ledger.TokenLedgerTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.TransactionData.Ledger.TokenLedger
  alias ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer
  alias ArchethicClient.Crypto
  alias ArchethicClient.Utils.VarInt

  describe "struct and instantiation" do
    test "can be created with default empty transfers" do
      token_ledger = %TokenLedger{}
      assert token_ledger.transfers == []
    end

    test "can be created with a list of transfers" do
      transfer1 = %Transfer{
        token_address: Crypto.derive_address("seed_token_addr1", 0),
        to: Crypto.derive_address("seed_token_to1", 0),
        amount: 100,
        token_id: 1
      }
      transfer2 = %Transfer{
        token_address: Crypto.derive_address("seed_token_addr2", 0),
        to: Crypto.derive_address("seed_token_to2", 0),
        amount: 200,
        token_id: 2
      }
      token_ledger = %TokenLedger{transfers: [transfer1, transfer2]}
      assert token_ledger.transfers == [transfer1, transfer2]
    end
  end

  describe "to_map/1" do
    test "converts a TokenLedger struct to the expected map format" do
      transfer = %Transfer{
        token_address: Crypto.derive_address("seed_token_map_addr", 0),
        to: Crypto.derive_address("seed_token_map_to", 0),
        amount: 150,
        token_id: 3
      }
      token_ledger = %TokenLedger{transfers: [transfer]}

      expected_map = %{transfers: [Transfer.to_map(transfer)]}
      assert TokenLedger.to_map(token_ledger) == expected_map
    end

    test "converts with empty transfers list" do
      token_ledger = %TokenLedger{transfers: []}
      expected_map = %{transfers: []}
      assert TokenLedger.to_map(token_ledger) == expected_map
    end
  end

  describe "serialize/1" do
    test "correctly serializes a TokenLedger struct with transfers" do
      transfer1 = %Transfer{
        token_address: Crypto.derive_address("seed_tk_ser_addr1", 0),
        to: Crypto.derive_address("seed_tk_ser_to1", 0),
        amount: 50,
        token_id: 10
      }
      transfer2 = %Transfer{
        token_address: Crypto.derive_address("seed_tk_ser_addr2", 0),
        to: Crypto.derive_address("seed_tk_ser_to2", 0),
        amount: 75,
        token_id: 20
      }
      token_ledger = %TokenLedger{transfers: [transfer1, transfer2]}

      serialized_transfer1 = Transfer.serialize(transfer1)
      serialized_transfer2 = Transfer.serialize(transfer2)
      transfers_bin = <<serialized_transfer1::binary, serialized_transfer2::binary>>
      count_bin = VarInt.from_value(2)

      expected_serialization = <<count_bin::binary, transfers_bin::binary>>
      assert TokenLedger.serialize(token_ledger) == expected_serialization
    end

    test "correctly serializes with empty transfers list" do
      token_ledger = %TokenLedger{transfers: []}
      count_bin = VarInt.from_value(0)
      transfers_bin = <<>>

      expected_serialization = <<count_bin::binary, transfers_bin::binary>>
      assert TokenLedger.serialize(token_ledger) == expected_serialization
      assert expected_serialization == <<1, 0>> # VarInt for 0 is <<1,0>>
    end
  end
end
