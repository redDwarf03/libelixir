defmodule ArchethicClient.CryptoTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.Crypto
  # For checking key prefixes
  alias ArchethicClient.Crypto.ID

  describe "generate_deterministic_keypair/2" do
    test "generates different keys for different seeds (default options)" do
      {pub1, priv1} = Crypto.generate_deterministic_keypair("seed1")
      {pub2, priv2} = Crypto.generate_deterministic_keypair("seed2")

      assert pub1 != pub2
      assert priv1 != priv2
    end

    test "generates the same keys for the same seed (default options)" do
      {pub1, priv1} = Crypto.generate_deterministic_keypair("common_seed")
      {pub2, priv2} = Crypto.generate_deterministic_keypair("common_seed")

      assert pub1 == pub2
      assert priv1 == priv2
    end

    test "generates Ed25519 keys by default with software origin" do
      {pub, _priv} = Crypto.generate_deterministic_keypair("ed_seed")
      <<curve_id::8, origin_id::8, _rest::binary>> = pub
      assert ID.to_curve(curve_id) == :ed25519
      assert ID.to_origin(origin_id) == :software
    end

    test "generates keys for :secp256r1 curve" do
      {pub, _priv} = Crypto.generate_deterministic_keypair("secp256r1_seed", curve: :secp256r1)
      <<curve_id::8, origin_id::8, _rest::binary>> = pub
      assert ID.to_curve(curve_id) == :secp256r1
      # Default origin
      assert ID.to_origin(origin_id) == :software
    end

    test "generates keys for :secp256k1 curve" do
      {pub, _priv} = Crypto.generate_deterministic_keypair("secp256k1_seed", curve: :secp256k1)
      <<curve_id::8, origin_id::8, _rest::binary>> = pub
      assert ID.to_curve(curve_id) == :secp256k1
      # Default origin
      assert ID.to_origin(origin_id) == :software
    end

    test "generates keys with :on_chain_wallet origin" do
      {pub, _priv} = Crypto.generate_deterministic_keypair("origin_seed", origin: :on_chain_wallet)
      <<curve_id::8, origin_id::8, _rest::binary>> = pub
      # Default curve
      assert ID.to_curve(curve_id) == :ed25519
      assert ID.to_origin(origin_id) == :on_chain_wallet
    end

    test "generates keys with specific curve and origin" do
      {pub, _priv} = Crypto.generate_deterministic_keypair("specific_seed", curve: :secp256r1, origin: :tpm)
      <<curve_id::8, origin_id::8, _rest::binary>> = pub
      assert ID.to_curve(curve_id) == :secp256r1
      assert ID.to_origin(origin_id) == :tpm
    end
  end

  describe "derive_keypair/3" do
    test "generates different keys for different indices (same seed, default opts)" do
      {pub1, priv1} = Crypto.derive_keypair("derive_seed", 0)
      {pub2, priv2} = Crypto.derive_keypair("derive_seed", 1)
      assert pub1 != pub2
      assert priv1 != priv2
    end

    test "generates the same keys for the same seed and index (default opts)" do
      {pub1, priv1} = Crypto.derive_keypair("derive_seed_same", 5)
      {pub2, priv2} = Crypto.derive_keypair("derive_seed_same", 5)
      assert pub1 == pub2
      assert priv1 == priv2
    end

    test "generates different keys for different seeds (same index, default opts)" do
      {pub1, priv1} = Crypto.derive_keypair("derive_seed_A", 3)
      {pub2, priv2} = Crypto.derive_keypair("derive_seed_B", 3)
      assert pub1 != pub2
      assert priv1 != priv2
    end

    test "generates Ed25519 keys by default with software origin" do
      {pub, _priv} = Crypto.derive_keypair("derive_ed_seed", 0)
      <<curve_id::8, origin_id::8, _rest::binary>> = pub
      assert ID.to_curve(curve_id) == :ed25519
      assert ID.to_origin(origin_id) == :software
    end

    test "generates keys for specific curve and origin via opts" do
      opts = [curve: :secp256k1, origin: :on_chain_wallet]
      {pub, _priv} = Crypto.derive_keypair("derive_specific_opts", 10, opts)
      <<curve_id::8, origin_id::8, _rest::binary>> = pub
      assert ID.to_curve(curve_id) == :secp256k1
      assert ID.to_origin(origin_id) == :on_chain_wallet
    end
  end

  describe "sign/2 and verify?/3" do
    test "correctly signs and verifies data with Ed25519 keys" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("sign_verify_seed_ed25519")
      data_to_sign = "This is some data to sign."

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, data_to_sign, pub_key) == true
    end

    test "fails to verify with different data (Ed25519)" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("sign_verify_seed_ed25519_diff_data")
      data_to_sign = "Original data"
      different_data = "Tampered data"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, different_data, pub_key) == false
    end

    test "fails to verify with different public key (Ed25519)" do
      {_pub_key, priv_key} = Crypto.generate_deterministic_keypair("sign_verify_seed_ed25519_orig_key")

      {different_pub_key, _different_priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_ed25519_diff_key")

      data_to_sign = "Some data"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, data_to_sign, different_pub_key) == false
    end

    test "fails to verify with tampered signature (Ed25519)" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("sign_verify_seed_ed25519_tamper_sig")
      data_to_sign = "Yet another piece of data"

      signature = Crypto.sign(data_to_sign, priv_key)
      # Tamper the signature by appending data to make it invalid.
      tampered_signature = signature <> "tamper"

      assert Crypto.verify?(tampered_signature, data_to_sign, pub_key) == false
    end

    # Tests for secp256r1
    test "correctly signs and verifies data with secp256r1 keys" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("sign_verify_seed_secp256r1", curve: :secp256r1)
      data_to_sign = "Data for secp256r1"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, data_to_sign, pub_key) == true
    end

    test "fails to verify with different data (secp256r1)" do
      {pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256r1_diff_data", curve: :secp256r1)

      data_to_sign = "Original secp256r1 data"
      different_data = "Tampered secp256r1 data"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, different_data, pub_key) == false
    end

    test "fails to verify with different public key (secp256r1)" do
      {_pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256r1_orig_key", curve: :secp256r1)

      {different_pub_key, _different_priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256r1_diff_key", curve: :secp256r1)

      data_to_sign = "Some secp256r1 data"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, data_to_sign, different_pub_key) == false
    end

    test "fails to verify with tampered signature (secp256r1)" do
      {pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256r1_tamper_sig", curve: :secp256r1)

      data_to_sign = "Untampered secp256r1 data"

      signature = Crypto.sign(data_to_sign, priv_key)
      tampered_signature = signature <> "tamper"

      assert Crypto.verify?(tampered_signature, data_to_sign, pub_key) == false
    end

    # Tests for secp256k1
    test "correctly signs and verifies data with secp256k1 keys" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("sign_verify_seed_secp256k1", curve: :secp256k1)
      data_to_sign = "Data for secp256k1"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, data_to_sign, pub_key) == true
    end

    test "fails to verify with different data (secp256k1)" do
      {pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256k1_diff_data", curve: :secp256k1)

      data_to_sign = "Original secp256k1 data"
      different_data = "Tampered secp256k1 data"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, different_data, pub_key) == false
    end

    test "fails to verify with different public key (secp256k1)" do
      {_pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256k1_orig_key", curve: :secp256k1)

      {different_pub_key, _different_priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256k1_diff_key", curve: :secp256k1)

      data_to_sign = "Some secp256k1 data"

      signature = Crypto.sign(data_to_sign, priv_key)

      assert Crypto.verify?(signature, data_to_sign, different_pub_key) == false
    end

    test "fails to verify with tampered signature (secp256k1)" do
      {pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("sign_verify_seed_secp256k1_tamper_sig", curve: :secp256k1)

      data_to_sign = "Untampered secp256k1 data"

      signature = Crypto.sign(data_to_sign, priv_key)
      tampered_signature = signature <> "tamper"

      assert Crypto.verify?(tampered_signature, data_to_sign, pub_key) == false
    end
  end

  describe "ec_encrypt/2, ec_decrypt/2, and ec_decrypt!/2" do
    test "correctly encrypts and decrypts data with Ed25519 keys" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("encrypt_decrypt_seed_ed25519")
      original_message = "This is a secret message for Ed25519."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)
      assert ciphertext != original_message

      # Test ec_decrypt/2
      assert Crypto.ec_decrypt(ciphertext, priv_key) == {:ok, original_message}

      # Test ec_decrypt!/2
      assert Crypto.ec_decrypt!(ciphertext, priv_key) == original_message
    end

    test "fails to decrypt with wrong private key (Ed25519)" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("enc_dec_seed_ed25519_orig_key")
      {_other_pub_key, other_priv_key} = Crypto.generate_deterministic_keypair("enc_dec_seed_ed25519_wrong_key")
      original_message = "Another secret message."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)

      assert Crypto.ec_decrypt(ciphertext, other_priv_key) == {:error, :decryption_failed}

      assert_raise RuntimeError, "Decryption failed", fn ->
        Crypto.ec_decrypt!(ciphertext, other_priv_key)
      end
    end

    test "fails to decrypt with tampered ciphertext (Ed25519)" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("enc_dec_seed_ed25519_tamper_cipher")
      original_message = "Sensitive information here."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)
      tampered_ciphertext = ciphertext <> "tamper"

      assert Crypto.ec_decrypt(tampered_ciphertext, priv_key) == {:error, :decryption_failed}

      assert_raise RuntimeError, "Decryption failed", fn ->
        Crypto.ec_decrypt!(tampered_ciphertext, priv_key)
      end
    end

    # Tests for secp256r1
    test "correctly encrypts and decrypts data with secp256r1 keys" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("enc_dec_seed_secp256r1", curve: :secp256r1)
      original_message = "This is a secret message for secp256r1."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)
      assert ciphertext != original_message

      assert Crypto.ec_decrypt(ciphertext, priv_key) == {:ok, original_message}
      assert Crypto.ec_decrypt!(ciphertext, priv_key) == original_message
    end

    test "fails to decrypt with wrong private key (secp256r1)" do
      {pub_key, _priv_key} =
        Crypto.generate_deterministic_keypair("enc_dec_seed_secp256r1_orig_key", curve: :secp256r1)

      {_other_pub_key, other_priv_key} =
        Crypto.generate_deterministic_keypair("enc_dec_seed_secp256r1_wrong_key", curve: :secp256r1)

      original_message = "Another secret for secp256r1."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)

      assert Crypto.ec_decrypt(ciphertext, other_priv_key) == {:error, :decryption_failed}

      assert_raise RuntimeError, "Decryption failed", fn ->
        Crypto.ec_decrypt!(ciphertext, other_priv_key)
      end
    end

    test "fails to decrypt with tampered ciphertext (secp256r1)" do
      {pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("enc_dec_seed_secp256r1_tamper_cipher", curve: :secp256r1)

      original_message = "Sensitive secp256r1 data."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)
      tampered_ciphertext = ciphertext <> "tamper"

      assert Crypto.ec_decrypt(tampered_ciphertext, priv_key) == {:error, :decryption_failed}

      assert_raise RuntimeError, "Decryption failed", fn ->
        Crypto.ec_decrypt!(tampered_ciphertext, priv_key)
      end
    end

    # Tests for secp256k1
    test "correctly encrypts and decrypts data with secp256k1 keys" do
      {pub_key, priv_key} = Crypto.generate_deterministic_keypair("enc_dec_seed_secp256k1", curve: :secp256k1)
      original_message = "This is a secret message for secp256k1."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)
      assert ciphertext != original_message

      assert Crypto.ec_decrypt(ciphertext, priv_key) == {:ok, original_message}
      assert Crypto.ec_decrypt!(ciphertext, priv_key) == original_message
    end

    test "fails to decrypt with wrong private key (secp256k1)" do
      {pub_key, _priv_key} =
        Crypto.generate_deterministic_keypair("enc_dec_seed_secp256k1_orig_key", curve: :secp256k1)

      {_other_pub_key, other_priv_key} =
        Crypto.generate_deterministic_keypair("enc_dec_seed_secp256k1_wrong_key", curve: :secp256k1)

      original_message = "Another secret for secp256k1."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)

      assert Crypto.ec_decrypt(ciphertext, other_priv_key) == {:error, :decryption_failed}

      assert_raise RuntimeError, "Decryption failed", fn ->
        Crypto.ec_decrypt!(ciphertext, other_priv_key)
      end
    end

    test "fails to decrypt with tampered ciphertext (secp256k1)" do
      {pub_key, priv_key} =
        Crypto.generate_deterministic_keypair("enc_dec_seed_secp256k1_tamper_cipher", curve: :secp256k1)

      original_message = "Sensitive secp256k1 data."

      ciphertext = Crypto.ec_encrypt(original_message, pub_key)
      tampered_ciphertext = ciphertext <> "tamper"

      assert Crypto.ec_decrypt(tampered_ciphertext, priv_key) == {:error, :decryption_failed}

      assert_raise RuntimeError, "Decryption failed", fn ->
        Crypto.ec_decrypt!(tampered_ciphertext, priv_key)
      end
    end
  end

  describe "hash/1 and hash/2" do
    test "hashes data correctly with default algorithm (sha256)" do
      data = "test data for default hash"
      hashed_once = Crypto.hash(data)
      hashed_twice = Crypto.hash(data)

      # Check determinism
      assert hashed_once == hashed_twice

      # Check prepended byte for sha256
      <<id_byte::8, _rest::binary>> = hashed_once
      assert ID.from_hash(:sha256) == id_byte

      # Check that hash/1 calls hash/2 with default algo
      assert Crypto.hash(data, :sha256) == hashed_once
    end

    test "hashes data correctly with :sha256" do
      data = "test data for sha256"
      algo = :sha256
      hashed_once = Crypto.hash(data, algo)
      hashed_twice = Crypto.hash(data, algo)

      assert hashed_once == hashed_twice
      <<id_byte::8, _rest::binary>> = hashed_once
      assert ID.from_hash(algo) == id_byte
      # ID byte + SHA256 size
      assert byte_size(hashed_once) == 1 + 32
    end

    test "hashes data correctly with :sha512" do
      data = "test data for sha512"
      algo = :sha512
      hashed_once = Crypto.hash(data, algo)
      hashed_twice = Crypto.hash(data, algo)

      assert hashed_once == hashed_twice
      <<id_byte::8, _rest::binary>> = hashed_once
      assert ID.from_hash(algo) == id_byte
      # ID byte + SHA512 size
      assert byte_size(hashed_once) == 1 + 64
    end

    test "hashes data correctly with :sha3_256" do
      data = "test data for sha3_256"
      algo = :sha3_256
      hashed_once = Crypto.hash(data, algo)
      hashed_twice = Crypto.hash(data, algo)

      assert hashed_once == hashed_twice
      <<id_byte::8, _rest::binary>> = hashed_once
      assert ID.from_hash(algo) == id_byte
      # ID byte + SHA3_256 size
      assert byte_size(hashed_once) == 1 + 32
    end

    test "hashes data correctly with :sha3_512" do
      data = "test data for sha3_512"
      algo = :sha3_512
      hashed_once = Crypto.hash(data, algo)
      hashed_twice = Crypto.hash(data, algo)

      assert hashed_once == hashed_twice
      <<id_byte::8, _rest::binary>> = hashed_once
      assert ID.from_hash(algo) == id_byte
      # ID byte + SHA3_512 size
      assert byte_size(hashed_once) == 1 + 64
    end

    test "hashes data correctly with :blake2b" do
      data = "test data for blake2b"
      algo = :blake2b
      hashed_once = Crypto.hash(data, algo)
      hashed_twice = Crypto.hash(data, algo)

      assert hashed_once == hashed_twice
      <<id_byte::8, _rest::binary>> = hashed_once
      assert ID.from_hash(algo) == id_byte
      # Blake2b default output is 512 bits (64 bytes) in :crypto.hash
      # ID byte + Blake2b size
      assert byte_size(hashed_once) == 1 + 64
    end

    test "produces different hashes for different data" do
      data1 = "some data"
      data2 = "different data"
      algo = :sha256

      assert Crypto.hash(data1, algo) != Crypto.hash(data2, algo)
    end

    test "produces different hashes for different algorithms" do
      data = "common data"
      assert Crypto.hash(data, :sha256) != Crypto.hash(data, :sha512)
    end
  end

  describe "address utility functions" do
    test "derive_public_key_address/1 with Ed25519 key and default hash" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("dpka_ed25519_default_hash")
      address = Crypto.derive_public_key_address(pub_key)

      # Address should be: <<curve_id::8, hash_id::8, _rest_of_hash::binary>>
      <<addr_curve_id::8, addr_hash_id::8, _hashed_pk::binary>> = address

      # Extract original curve from pub_key
      <<key_curve_id::8, _key_origin_id::8, _key_data::binary>> = pub_key

      assert addr_curve_id == key_curve_id
      # Check against actual default
      assert addr_hash_id == ID.from_hash(Crypto.default_hash())

      # Check determinism
      assert Crypto.derive_public_key_address(pub_key) == address
    end

    test "derive_public_key_address/2 with Ed25519 key and :blake2b hash" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("dpka_ed25519_blake2b")
      hash_algo = :blake2b
      address = Crypto.derive_public_key_address(pub_key, hash_algo)

      <<addr_curve_id::8, addr_hash_id::8, _hashed_pk::binary>> = address
      <<key_curve_id::8, _key_origin_id::8, _key_data::binary>> = pub_key

      assert addr_curve_id == key_curve_id
      assert addr_hash_id == ID.from_hash(hash_algo)
      # Determinism
      assert Crypto.derive_public_key_address(pub_key, hash_algo) == address
    end

    test "derive_public_key_address/2 with secp256r1 key and :sha256 hash" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("dpka_secp256r1_sha256", curve: :secp256r1)
      hash_algo = :sha256
      address = Crypto.derive_public_key_address(pub_key, hash_algo)

      <<addr_curve_id::8, addr_hash_id::8, _hashed_pk::binary>> = address
      <<key_curve_id::8, _key_origin_id::8, _key_data::binary>> = pub_key

      assert addr_curve_id == key_curve_id
      assert ID.to_curve(addr_curve_id) == :secp256r1
      assert addr_hash_id == ID.from_hash(hash_algo)
      # Determinism
      assert Crypto.derive_public_key_address(pub_key, hash_algo) == address
    end

    test "derive_public_key_address/2 with secp256k1 key and :sha512 hash" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("dpka_secp256k1_sha512", curve: :secp256k1)
      hash_algo = :sha512
      address = Crypto.derive_public_key_address(pub_key, hash_algo)

      <<addr_curve_id::8, addr_hash_id::8, _hashed_pk::binary>> = address
      <<key_curve_id::8, _key_origin_id::8, _key_data::binary>> = pub_key

      assert addr_curve_id == key_curve_id
      assert ID.to_curve(addr_curve_id) == :secp256k1
      assert addr_hash_id == ID.from_hash(hash_algo)
      # Determinism
      assert Crypto.derive_public_key_address(pub_key, hash_algo) == address
    end

    # Tests for derive_address/3
    test "derive_address/3 generates different addresses for different indices" do
      seed = "derive_address_seed"
      address1 = Crypto.derive_address(seed, 0)
      address2 = Crypto.derive_address(seed, 1)
      assert address1 != address2
    end

    test "derive_address/3 generates same address for same seed, index and options" do
      seed = "derive_address_seed_same"
      index = 5
      opts = [curve: :secp256r1, hash_algo: :blake2b]
      address1 = Crypto.derive_address(seed, index, opts)
      address2 = Crypto.derive_address(seed, index, opts)
      assert address1 == address2

      # Verify prefix based on opts
      <<addr_curve_id::8, addr_hash_id::8, _hashed_pk::binary>> = address1
      assert ID.to_curve(addr_curve_id) == :secp256r1
      assert ID.from_hash(:blake2b) == addr_hash_id
    end

    test "derive_address/3 uses default curve and hash if not specified" do
      seed = "derive_address_defaults"
      index = 0
      address = Crypto.derive_address(seed, index)

      <<addr_curve_id::8, addr_hash_id::8, _hashed_pk::binary>> = address
      assert ID.to_curve(addr_curve_id) == Crypto.default_curve()
      assert ID.from_hash(Crypto.default_hash()) == addr_hash_id
    end
  end

  describe "validation utility functions" do
    # Tests for valid_public_key?/1
    test "valid_public_key?/1 identifies valid Ed25519 keys" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("valid_pk_ed25519", curve: :ed25519)
      assert Crypto.valid_public_key?(pub_key) == true
    end

    test "valid_public_key?/1 identifies valid secp256r1 keys" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("valid_pk_secp256r1", curve: :secp256r1)
      assert Crypto.valid_public_key?(pub_key) == true
    end

    test "valid_public_key?/1 identifies valid secp256k1 keys" do
      {pub_key, _priv_key} = Crypto.generate_deterministic_keypair("valid_pk_secp256k1", curve: :secp256k1)
      assert Crypto.valid_public_key?(pub_key) == true
    end

    test "valid_public_key?/1 rejects key with invalid curve ID" do
      # Ed25519 is ID 0, secp256r1 is 1, secp256k1 is 2. Use 3 for invalid curve ID.
      # Correct length for Ed25519 (32 bytes data + 2 prefix = 34 total)
      # Origin: software
      invalid_curve_key = <<3::8, 1::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_public_key?(invalid_curve_key) == false
    end

    test "valid_public_key?/1 rejects Ed25519 key with wrong length" do
      # Ed25519 pubkey data is 32 bytes. Prepend ID for Ed25519 (0) and origin (e.g. software, 1)
      short_key = <<ID.from_curve(:ed25519)::8, 1::8>> <> :crypto.strong_rand_bytes(31)
      long_key = <<ID.from_curve(:ed25519)::8, 1::8>> <> :crypto.strong_rand_bytes(33)
      assert Crypto.valid_public_key?(short_key) == false
      assert Crypto.valid_public_key?(long_key) == false
    end

    test "valid_public_key?/1 rejects secp256r1 key with wrong length" do
      # secp256r1 pubkey data is 65 bytes (uncompressed). Prepend IDs.
      short_key = <<ID.from_curve(:secp256r1)::8, 1::8>> <> :crypto.strong_rand_bytes(64)
      long_key = <<ID.from_curve(:secp256r1)::8, 1::8>> <> :crypto.strong_rand_bytes(66)
      assert Crypto.valid_public_key?(short_key) == false
      assert Crypto.valid_public_key?(long_key) == false
    end

    test "valid_public_key?/1 rejects non-key binary" do
      assert Crypto.valid_public_key?("not_a_key") == false
      assert Crypto.valid_public_key?(<<1, 2, 3>>) == false
    end

    # Tests for valid_hash?/1
    test "valid_hash?/1 identifies valid SHA256 hash" do
      valid_sha256 = <<ID.from_hash(:sha256)::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_hash?(valid_sha256) == true
    end

    test "valid_hash?/1 identifies valid SHA512 hash" do
      valid_sha512 = <<ID.from_hash(:sha512)::8>> <> :crypto.strong_rand_bytes(64)
      assert Crypto.valid_hash?(valid_sha512) == true
    end

    test "valid_hash?/1 identifies valid SHA3_256 hash" do
      valid_sha3_256 = <<ID.from_hash(:sha3_256)::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_hash?(valid_sha3_256) == true
    end

    test "valid_hash?/1 identifies valid SHA3_512 hash" do
      valid_sha3_512 = <<ID.from_hash(:sha3_512)::8>> <> :crypto.strong_rand_bytes(64)
      assert Crypto.valid_hash?(valid_sha3_512) == true
    end

    test "valid_hash?/1 identifies valid Blake2b hash" do
      # Blake2b in :crypto.hash defaults to 512-bit (64 bytes) output
      valid_blake2b = <<ID.from_hash(:blake2b)::8>> <> :crypto.strong_rand_bytes(64)
      assert Crypto.valid_hash?(valid_blake2b) == true
    end

    test "valid_hash?/1 identifies valid hash with ID 5 (32 bytes)" do
      valid_hash_id5 = <<5::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_hash?(valid_hash_id5) == true
    end

    test "valid_hash?/1 rejects hash with invalid ID" do
      # ID 6 is not defined
      invalid_id_hash = <<6::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_hash?(invalid_id_hash) == false
    end

    test "valid_hash?/1 rejects SHA256 with wrong length" do
      short_sha256 = <<ID.from_hash(:sha256)::8>> <> :crypto.strong_rand_bytes(31)
      long_sha256 = <<ID.from_hash(:sha256)::8>> <> :crypto.strong_rand_bytes(33)
      assert Crypto.valid_hash?(short_sha256) == false
      assert Crypto.valid_hash?(long_sha256) == false
    end

    test "valid_hash?/1 rejects SHA512 with wrong length" do
      short_sha512 = <<ID.from_hash(:sha512)::8>> <> :crypto.strong_rand_bytes(63)
      long_sha512 = <<ID.from_hash(:sha512)::8>> <> :crypto.strong_rand_bytes(65)
      assert Crypto.valid_hash?(short_sha512) == false
      assert Crypto.valid_hash?(long_sha512) == false
    end

    test "valid_hash?/1 rejects non-hash binary" do
      assert Crypto.valid_hash?("not_a_hash") == false
      assert Crypto.valid_hash?(<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10>>) == false
    end

    # Tests for valid_address?/1
    test "valid_address?/1 identifies valid addresses" do
      # Valid Ed25519 key, SHA256 hash
      ed25519_sha256_addr = <<ID.from_curve(:ed25519)::8, ID.from_hash(:sha256)::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_address?(ed25519_sha256_addr) == true

      # Valid secp256r1 key, Blake2b hash
      secp256r1_blake2b_addr =
        <<ID.from_curve(:secp256r1)::8, ID.from_hash(:blake2b)::8>> <> :crypto.strong_rand_bytes(64)

      assert Crypto.valid_address?(secp256r1_blake2b_addr) == true
    end

    test "valid_address?/1 rejects address with invalid curve ID" do
      # Curve ID 3 is invalid
      invalid_curve_addr = <<3::8, ID.from_hash(:sha256)::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_address?(invalid_curve_addr) == false
    end

    test "valid_address?/1 rejects address with valid curve ID but invalid hash part" do
      # Valid Ed25519 curve, but invalid hash (wrong ID for its length)
      # Hash ID 6 is invalid
      addr_invalid_hash_id = <<ID.from_curve(:ed25519)::8, 6::8>> <> :crypto.strong_rand_bytes(32)
      assert Crypto.valid_address?(addr_invalid_hash_id) == false

      # Valid Ed25519 curve, SHA256 hash ID, but wrong length for SHA256
      addr_invalid_hash_len = <<ID.from_curve(:ed25519)::8, ID.from_hash(:sha256)::8>> <> :crypto.strong_rand_bytes(31)
      assert Crypto.valid_address?(addr_invalid_hash_len) == false
    end

    test "valid_address?/1 rejects non-address binary" do
      assert Crypto.valid_address?("not_an_address") == false
      assert Crypto.valid_address?(<<1, 2, 3, 4>>) == false
    end
  end
end
