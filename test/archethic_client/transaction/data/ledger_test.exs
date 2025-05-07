defmodule ArchethicClient.TransactionData.LedgerTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.TransactionData.Ledger
  alias ArchethicClient.TransactionData.Ledger.UCOLedger
  alias ArchethicClient.TransactionData.Ledger.TokenLedger
  alias ArchethicClient.Crypto

  describe "struct and instantiation" do
    test "can be created with default UCOLedger and TokenLedger" do
      ledger = %Ledger{}
      assert ledger.uco == %UCOLedger{}
      assert ledger.token == %TokenLedger{}
    end

    test "can be created with specific UCOLedger and TokenLedger" do
      uco_transfer = %UCOLedger.Transfer{
        to: Crypto.derive_address("seed_uco_to", 0),
        amount: 100
      }
      token_transfer = %TokenLedger.Transfer{
        token_address: Crypto.derive_address("seed_token_addr", 0),
        to: Crypto.derive_address("seed_token_to", 0),
        amount: 50,
        token_id: 1
      }
      uco_ledger = %UCOLedger{transfers: [uco_transfer]}
      token_ledger = %TokenLedger{transfers: [token_transfer]}

      ledger = %Ledger{uco: uco_ledger, token: token_ledger}

      assert ledger.uco == uco_ledger
      assert ledger.token == token_ledger
    end
  end

  describe "to_map/1" do
    test "converts a Ledger struct to the expected map format" do
      uco_transfer = %UCOLedger.Transfer{
        to: Crypto.derive_address("seed_uco_to_map", 0),
        amount: 200
      }
      token_transfer = %TokenLedger.Transfer{
        token_address: Crypto.derive_address("seed_token_addr_map", 0),
        to: Crypto.derive_address("seed_token_to_map", 0),
        amount: 75,
        token_id: 2
      }
      uco_ledger = %UCOLedger{transfers: [uco_transfer]}
      token_ledger = %TokenLedger{transfers: [token_transfer]}
      ledger = %Ledger{uco: uco_ledger, token: token_ledger}

      expected_map = %{
        uco: UCOLedger.to_map(uco_ledger),
        token: TokenLedger.to_map(token_ledger)
      }
      assert Ledger.to_map(ledger) == expected_map
    end

    test "to_map(nil) returns a map with default empty uco and token ledger maps" do
      expected_map = %{
        uco: UCOLedger.to_map(%UCOLedger{}), # Default empty UCO ledger map
        token: TokenLedger.to_map(%TokenLedger{}) # Default empty Token ledger map
      }
      assert Ledger.to_map(nil) == expected_map
    end

    test "to_map/1 with empty ledgers" do
      ledger = %Ledger{uco: %UCOLedger{}, token: %TokenLedger{}}
      expected_map = %{
        uco: UCOLedger.to_map(%UCOLedger{}),
        token: TokenLedger.to_map(%TokenLedger{})
      }
      assert Ledger.to_map(ledger) == expected_map
    end
  end

  describe "serialize/1" do
    test "correctly serializes a Ledger struct" do
      uco_transfer = %UCOLedger.Transfer{
        to: Crypto.derive_address("seed_uco_serialize", 0),
        amount: 300
      }
      token_transfer = %TokenLedger.Transfer{
        token_address: Crypto.derive_address("seed_token_addr_serialize", 0),
        to: Crypto.derive_address("seed_token_to_serialize", 0),
        amount: 125,
        token_id: 3
      }
      uco_ledger = %UCOLedger{transfers: [uco_transfer]}
      token_ledger = %TokenLedger{transfers: [token_transfer]}
      ledger = %Ledger{uco: uco_ledger, token: token_ledger}

      serialized_uco = UCOLedger.serialize(uco_ledger)
      serialized_token = TokenLedger.serialize(token_ledger)
      expected_serialization = <<serialized_uco::binary, serialized_token::binary>>

      assert Ledger.serialize(ledger) == expected_serialization
    end

    test "correctly serializes with empty uco and token ledgers" do
      uco_ledger = %UCOLedger{} # Empty transfers
      token_ledger = %TokenLedger{} # Empty transfers
      ledger = %Ledger{uco: uco_ledger, token: token_ledger}

      serialized_uco = UCOLedger.serialize(uco_ledger)
      serialized_token = TokenLedger.serialize(token_ledger)
      expected_serialization = <<serialized_uco::binary, serialized_token::binary>>

      assert Ledger.serialize(ledger) == expected_serialization
      # UCOLedger (empty) serializes to <<1,0>> (1 byte for length 0)
      # TokenLedger (empty) serializes to <<1,0>> (1 byte for length 0)
      assert expected_serialization == <<1, 0, 1, 0>>, "Expected empty UCO and Token ledgers to serialize to <<1,0,1,0>>"
    end
  end
end
