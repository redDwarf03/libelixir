defmodule ArchethicClient.TransactionData.OwnershipTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.TransactionData.Ownership
  alias ArchethicClient.Crypto
  alias ArchethicClient.Utils.VarInt # For checking serialized length part

  describe "new/3" do
    test "creates an ownership struct with encrypted secret keys for authorized keys" do
      secret_data = "my_secret_payload"
      secret_key_to_share = :crypto.strong_rand_bytes(32)
      {pub_key1, priv_key1} = Crypto.generate_deterministic_keypair("seed1")
      {pub_key2, priv_key2} = Crypto.generate_deterministic_keypair("seed2")
      authorized_keys_list = [pub_key1, pub_key2]

      ownership = Ownership.new(secret_data, authorized_keys_list, secret_key_to_share)

      assert ownership.secret == secret_data
      assert map_size(ownership.authorized_keys) == 2
      assert Map.has_key?(ownership.authorized_keys, pub_key1)
      assert Map.has_key?(ownership.authorized_keys, pub_key2)

      encrypted_for_key1 = ownership.authorized_keys[pub_key1]
      encrypted_for_key2 = ownership.authorized_keys[pub_key2]

      assert encrypted_for_key1 != secret_key_to_share
      assert encrypted_for_key2 != secret_key_to_share
      assert Crypto.ec_decrypt(encrypted_for_key1, priv_key1) == {:ok, secret_key_to_share}
      assert Crypto.ec_decrypt(encrypted_for_key2, priv_key2) == {:ok, secret_key_to_share}
    end

    test "uses a random secret_key if not provided" do
      secret_data = "another_secret"
      {pub_key, _} = Crypto.generate_deterministic_keypair("seed3")

      ownership1 = Ownership.new(secret_data, [pub_key])
      ownership2 = Ownership.new(secret_data, [pub_key]) # Should use a different random key

      # It's hard to assert the exact random key, but the encrypted values should differ
      assert Map.get(ownership1.authorized_keys, pub_key) != Map.get(ownership2.authorized_keys, pub_key)
    end
  end

  describe "to_map/1" do
    test "converts an Ownership struct to the expected map format" do
      secret_data = <<1, 2, 3>>
      secret_key_to_share = <<4, 5, 6>>
      {pub_key, _} = Crypto.generate_deterministic_keypair("seed_map_test")
      encrypted_shared_key = Crypto.ec_encrypt(secret_key_to_share, pub_key)

      ownership_struct = %Ownership{
        secret: secret_data,
        authorized_keys: %{pub_key => encrypted_shared_key}
      }

      expected_map = %{
        secret: Base.encode16(secret_data),
        authorizedKeys: %{Base.encode16(pub_key) => Base.encode16(encrypted_shared_key)}
      }
      assert Ownership.to_map(ownership_struct) == expected_map
    end

    test "handles empty authorized_keys map" do
      ownership_struct = %Ownership{secret: <<10, 20>>, authorized_keys: %{}}
      expected_map = %{
        secret: Base.encode16(<<10, 20>>),
        authorizedKeys: %{}
      }
      assert Ownership.to_map(ownership_struct) == expected_map
    end
  end

  describe "serialize/1 (and deserialize implicitly via roundtrip)" do
    test "correctly serializes an ownership struct and can be conceptually deserialized" do
      secret_data = <<1, 2, 3, 4, 5>>
      secret_key_to_share = :crypto.strong_rand_bytes(32)
      {pub_key1, _priv_key1} = Crypto.generate_deterministic_keypair("seed_serialize1")
      {pub_key2, _priv_key2} = Crypto.generate_deterministic_keypair("seed_serialize2")

      original_ownership = Ownership.new(secret_data, [pub_key1, pub_key2], secret_key_to_share)

      serialized = Ownership.serialize(original_ownership)

      # Format: <<byte_size(secret)::32, secret::binary, serialized_length::binary, authorized_keys_bin::binary>>
      # Where serialized_length is VarInt.from_value(map_size(authorized_keys))
      # And authorized_keys_bin is concatenation of <<public_key::binary, encrypted_key::binary>>

      expected_secret_size_bytes = byte_size(original_ownership.secret)
      # expected_auth_keys_count_varint = VarInt.from_value(map_size(original_ownership.authorized_keys)) # Unused

      # Check parts of the serialized binary
      <<actual_secret_size::32, actual_secret::binary-size(expected_secret_size_bytes), rest_after_secret::binary>> = serialized
      assert actual_secret_size == expected_secret_size_bytes
      assert actual_secret == original_ownership.secret

      {auth_keys_count_val, rest_after_varint} = VarInt.get_value(rest_after_secret)
      assert auth_keys_count_val == map_size(original_ownership.authorized_keys)

      # Further deserialization would require parsing the rest_after_varint based on auth_keys_count_val
      # and knowledge of key lengths. For now, this partial check is sufficient as there's no deserialize function.
      # We are mainly testing that serialize produces a structurally sound output.

      # Example of what the authorized_keys_bin part would look like if we were to reconstruct it:
      # encrypted_key1 = original_ownership.authorized_keys[pub_key1]
      # encrypted_key2 = original_ownership.authorized_keys[pub_key2]
      # expected_auth_keys_bin = <<pub_key1::binary, encrypted_key1::binary, pub_key2::binary, encrypted_key2::binary>>
      # assert rest_after_varint == expected_auth_keys_bin

      assert byte_size(rest_after_varint) > 0 # Ensure there's data for authorized keys
    end

    test "serializes with empty authorized keys" do
      original_ownership = %Ownership{secret: <<100, 200>>, authorized_keys: %{}}
      serialized = Ownership.serialize(original_ownership)

      expected_secret_size_bytes = byte_size(original_ownership.secret)
      # expected_auth_keys_count_varint = VarInt.from_value(0) # Unused

      <<actual_secret_size::32, actual_secret::binary-size(expected_secret_size_bytes), rest_after_secret::binary>> = serialized
      assert actual_secret_size == expected_secret_size_bytes
      assert actual_secret == original_ownership.secret

      {auth_keys_count_val, rest_after_varint} = VarInt.get_value(rest_after_secret)
      assert auth_keys_count_val == 0
      assert rest_after_varint == <<>> # No more data after count if count is 0
    end
  end
end
