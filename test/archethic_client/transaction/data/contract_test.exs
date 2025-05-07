defmodule ArchethicClient.TransactionData.ContractTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.TransactionData.Contract
  # Used internally by Contract.serialize
  alias ArchethicClient.Utils.TypedEncoding

  describe "cast/1" do
    test "casts nil to nil" do
      assert Contract.cast(nil) == nil
    end

    test "casts a valid map to a Contract struct" do
      bytecode = <<1, 2, 3, 4>>
      manifest = %{"abi" => %{"functions" => [%{"name" => "init"}]}}
      expected_struct = %Contract{bytecode: bytecode, manifest: manifest}
      assert Contract.cast(%{bytecode: bytecode, manifest: manifest}) == expected_struct
    end

    test "returns error for map missing :manifest key" do
      assert Contract.cast(%{bytecode: <<1>>}) == {:error, :invalid_contract_input_map}
    end

    test "returns error for map missing :bytecode key" do
      assert Contract.cast(%{manifest: %{}}) == {:error, :invalid_contract_input_map}
    end

    test "returns error for map with wrong type for :manifest" do
      assert Contract.cast(%{bytecode: <<1>>, manifest: "not_a_map"}) == {:error, :invalid_contract_input_map}
    end

    test "returns error for non-map, non-nil input" do
      assert Contract.cast(:not_a_map) == {:error, :invalid_contract_input_map}
      assert Contract.cast("a string") == {:error, :invalid_contract_input_map}
    end
  end

  describe "to_map/1" do
    test "converts nil to nil" do
      assert Contract.to_map(nil) == nil
    end

    test "converts a Contract struct to the expected map format" do
      bytecode = <<0, 1, 2, 3, 255>>
      manifest_abi = %{"functions" => [%{"name" => "do_something"}], "state" => [%{"name" => "count"}]}
      manifest_upgrade = %{"from" => ["some_address_hash"]}
      manifest = %{"abi" => manifest_abi, "upgradeOpts" => manifest_upgrade}
      contract_struct = %Contract{bytecode: bytecode, manifest: manifest}

      expected_map = %{
        bytecode: Base.encode16(bytecode),
        manifest: %{
          abi: %{functions: [%{"name" => "do_something"}], state: [%{"name" => "count"}]},
          upgrade_opts: %{from: ["some_address_hash"]}
        }
      }

      assert Contract.to_map(contract_struct) == expected_map
    end

    test "converts a Contract struct with nil upgradeOpts to map" do
      bytecode = <<4, 5, 6>>
      manifest_abi = %{"functions" => [], "state" => []}
      manifest = %{"abi" => manifest_abi, "upgradeOpts" => nil}
      contract_struct = %Contract{bytecode: bytecode, manifest: manifest}

      expected_map = %{
        bytecode: Base.encode16(bytecode),
        manifest: %{
          abi: %{functions: [], state: []},
          upgrade_opts: nil
        }
      }

      assert Contract.to_map(contract_struct) == expected_map
    end
  end

  describe "serialize/2 and deserialize/3 (roundtrip)" do
    test "correctly serializes and deserializes a contract" do
      bytecode = <<10, 20, 30, 40, 50>>

      manifest = %{
        "abi" => %{
          "functions" => [%{"name" => "my_fun", "args" => ["u32"], "return" => "u64"}],
          "state" => [%{"name" => "owner", "type" => "address"}]
        },
        "version" => "1.0.0",
        "upgradeOpts" => nil
      }

      original_contract = %Contract{bytecode: bytecode, manifest: manifest}
      # Arbitrary version for serialization as per spec
      version = 1

      serialized_contract = Contract.serialize(original_contract, version)

      # Expected format: <<byte_size(bytecode)::32, bytecode::binary, TypedEncoding.serialize(manifest)::bitstring>>
      expected_bytecode_size = byte_size(bytecode)
      expected_serialized_manifest = TypedEncoding.serialize(manifest)
      # Manually construct for verification, though direct comparison is more robust
      manual_serialized = <<expected_bytecode_size::32, bytecode::binary, expected_serialized_manifest::binary>>
      assert serialized_contract == manual_serialized

      # Test deserialization (assuming :compact mode, as default in module if not specified)
      # The deserialize function in Contract.ex has a default for serialization_mode
      case Contract.deserialize(serialized_contract, version) do
        {deserialized_contract, rest_of_binary} ->
          assert deserialized_contract == original_contract
          # Expect no leftover binary
          assert rest_of_binary == <<>>

        other ->
          flunk("Deserialize did not return the expected tuple: #{inspect(other)}")
      end
    end

    test "handles empty bytecode and manifest" do
      original_contract = %Contract{bytecode: <<>>, manifest: %{}}
      version = 1
      serialized_contract = Contract.serialize(original_contract, version)

      case Contract.deserialize(serialized_contract, version, :compact) do
        {deserialized_contract, <<>>} ->
          assert deserialized_contract.bytecode == <<>>
          # Manifest might not be exactly %{} after TypedEncoding roundtrip if it adds default fields,
          # but it should be semantically equivalent or at least contain what was put in.
          # For an empty map, TypedEncoding.serialize(%{}) results in specific bytes.
          # And TypedEncoding.deserialize would return that.
          # Let's check the exact structure that TypedEncoding creates for empty map.
          # TypedEncoding.serialize(%{}) -> <<@type_map::8, 1, 0>>
          # So, after deserialize, manifest should be %{}
          assert deserialized_contract.manifest == %{}

        other ->
          flunk("Deserialize failed for empty contract: #{inspect(other)}")
      end
    end
  end
end
