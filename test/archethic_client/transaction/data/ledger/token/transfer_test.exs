defmodule ArchethicClient.TransactionData.Ledger.TokenLedger.TransferTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer
  alias ArchethicClient.Crypto
  alias ArchethicClient.Utils.VarInt

  describe "struct and instantiation" do
    test "can be created with valid fields" do
      token_address = Crypto.derive_address("seed_token_addr", 0)
      to_address = Crypto.derive_address("seed_token_to", 0)
      amount = 100
      token_id = 1
      conditions = [Crypto.derive_address("seed_condition_addr", 0)]

      transfer = %Transfer{
        token_address: token_address,
        to: to_address,
        amount: amount,
        token_id: token_id,
        conditions: conditions
      }

      assert transfer.token_address == token_address
      assert transfer.to == to_address
      assert transfer.amount == amount
      assert transfer.token_id == token_id
      assert transfer.conditions == conditions
    end

    test "can be created with default token_id and conditions" do
      token_address = Crypto.derive_address("seed_token_addr_def", 0)
      to_address = Crypto.derive_address("seed_token_to_def", 0)
      amount = 200

      transfer = %Transfer{
        token_address: token_address,
        to: to_address,
        amount: amount
      }
      assert transfer.token_id == 0
      assert transfer.conditions == []
    end
  end

  describe "to_map/1" do
    test "converts a Transfer struct to the expected map format with camelCase keys" do
      token_address = Crypto.derive_address("seed_token_map_addr", 0)
      to_address = Crypto.derive_address("seed_token_map_to", 0)
      amount = 300
      token_id = 5
      # conditions are not included in the map as per current implementation
      transfer = %Transfer{
        token_address: token_address,
        to: to_address,
        amount: amount,
        token_id: token_id,
        conditions: [Crypto.derive_address("seed_cond_map",0)]
      }

      expected_map = %{
        tokenAddress: Base.encode16(token_address),
        to: Base.encode16(to_address),
        amount: amount,
        tokenId: token_id
      }
      assert Transfer.to_map(transfer) == expected_map
    end
  end

  describe "serialize/1" do
    test "correctly serializes a Transfer struct" do
      token_address = Crypto.derive_address("seed_token_ser_addr", 0)
      to_address = Crypto.derive_address("seed_token_ser_to", 0)
      amount = 400
      token_id = 10
      # conditions are not serialized as per current implementation
      transfer = %Transfer{
        token_address: token_address,
        to: to_address,
        amount: amount,
        token_id: token_id
      }

      varint_token_id = VarInt.from_value(token_id)
      expected_serialization =
        <<token_address::binary, to_address::binary, amount::unsigned-integer-size(64), varint_token_id::binary>>

      assert Transfer.serialize(transfer) == expected_serialization
    end

    test "correctly serializes with token_id = 0" do
      token_address = Crypto.derive_address("seed_token_ser_addr_id0", 0)
      to_address = Crypto.derive_address("seed_token_ser_to_id0", 0)
      amount = 500
      token_id = 0 # Default value, should be VarInt encoded as <<1,0>>
      transfer = %Transfer{
        token_address: token_address,
        to: to_address,
        amount: amount,
        token_id: token_id
      }

      varint_token_id = VarInt.from_value(token_id) # <<1,0>>
      expected_serialization =
        <<token_address::binary, to_address::binary, amount::unsigned-integer-size(64), varint_token_id::binary>>

      assert Transfer.serialize(transfer) == expected_serialization
      assert varint_token_id == <<1,0>>
    end
  end
end
