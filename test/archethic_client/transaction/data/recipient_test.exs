defmodule ArchethicClient.TransactionData.RecipientTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.Crypto
  alias ArchethicClient.TransactionData.Recipient
  alias ArchethicClient.Utils.TypedEncoding

  describe "struct and basic instantiation" do
    test "can be created with valid fields" do
      address = Crypto.derive_address("seed_recipient", 0)
      action = "some_action"
      args = [1, "hello", true]

      recipient = %Recipient{address: address, action: action, args: args}

      assert recipient.address == address
      assert recipient.action == action
      assert recipient.args == args
    end

    test "can be created with nil action and args" do
      address = Crypto.derive_address("seed_recipient_nil", 0)
      recipient = %Recipient{address: address, action: nil, args: nil}

      assert recipient.address == address
      assert recipient.action == nil
      assert recipient.args == nil
    end

    test "can be created with empty args list" do
      address = Crypto.derive_address("seed_recipient_empty_args", 0)
      action = "action_no_args"
      recipient = %Recipient{address: address, action: action, args: []}

      assert recipient.address == address
      assert recipient.action == action
      assert recipient.args == []
    end
  end

  describe "to_map/1" do
    test "converts a Recipient struct to the expected map format" do
      address = Crypto.derive_address("seed_map", 0)
      action = "perform_task"
      args = [42, "data"]
      recipient = %Recipient{address: address, action: action, args: args}

      expected_map = %{
        address: Base.encode16(address),
        action: action,
        args: args
      }

      assert Recipient.to_map(recipient) == expected_map
    end

    test "handles nil action and args correctly in to_map/1" do
      address = Crypto.derive_address("seed_map_nil", 0)
      recipient = %Recipient{address: address, action: nil, args: nil}

      expected_map = %{
        address: Base.encode16(address),
        action: nil,
        args: nil
      }

      assert Recipient.to_map(recipient) == expected_map
    end
  end

  describe "serialize/1" do
    test "correctly serializes a Recipient struct with action and args" do
      # 34 bytes
      address = Crypto.derive_address("seed_serialize", 0)
      # 7 bytes
      action = "my_func"
      args = [123, "test"]
      recipient = %Recipient{address: address, action: action, args: args}

      serialized_arg1 = TypedEncoding.serialize(123)
      serialized_arg2 = TypedEncoding.serialize("test")
      serialized_args_binary = <<serialized_arg1::binary, serialized_arg2::binary>>

      expected_serialization =
        <<1::8, address::binary, byte_size(action)::8, action::binary, length(args)::8,
          serialized_args_binary::binary>>

      assert Recipient.serialize(recipient) == expected_serialization
    end

    test "correctly serializes with nil action and nil args" do
      address = Crypto.derive_address("seed_serialize_nil", 0)
      action = nil
      args = nil
      recipient = %Recipient{address: address, action: action, args: args}

      # With the fix in serialize/1: action || "", args || []
      # action becomes "", args becomes []
      expected_action_binary = ""
      expected_args_list_length = 0
      expected_serialized_args_binary = <<>>

      expected_serialization =
        <<1::8, address::binary, byte_size(expected_action_binary)::8, expected_action_binary::binary,
          expected_args_list_length::8, expected_serialized_args_binary::binary>>

      assert Recipient.serialize(recipient) == expected_serialization
    end

    test "correctly serializes with non-nil action and empty args list" do
      address = Crypto.derive_address("seed_serialize_empty_args", 0)
      action = "do_something"
      args = []
      recipient = %Recipient{address: address, action: action, args: args}

      serialized_args_binary = <<>>

      expected_serialization =
        <<1::8, address::binary, byte_size(action)::8, action::binary, length(args)::8,
          serialized_args_binary::binary>>

      assert Recipient.serialize(recipient) == expected_serialization
    end
  end
end
