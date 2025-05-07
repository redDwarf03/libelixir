defmodule ArchethicClient.TransactionData.Ownership do
  @moduledoc """
  Represents an ownership record for a secret within a transaction.

  An ownership consists of:
  - `secret`: The actual secret data (binary).
  - `authorized_keys`: A map where keys are the public keys (`Crypto.key/0`) of entities
    authorized to decrypt the `secret_key`, and values are the `secret_key` itself,
    encrypted with the corresponding public key.

  This module allows creating new ownership records, serializing them for inclusion
  in a transaction, and converting them to a map representation.
  The `secret_key` is an ephemeral key used to encrypt the main `secret` data if needed,
  or it can be the secret itself if it's already in a suitable format for encryption via ECIES by multiple public keys.
  Effectively, each authorized public key can decrypt its corresponding `encrypted_key` to get the `secret_key`,
  which can then be used to decrypt the main `secret` (if the main `secret` itself was encrypted with this `secret_key`).
  The current implementation in `new/3` directly stores the provided `secret` and encrypts the `secret_key` for each authorized public key.
  This implies the `secret` field should perhaps be named `encrypted_secret_payload` if it were to be encrypted by `secret_key`,
  or the `secret_key` is what is being shared, and `secret` is some metadata/identifier.
  Given the example `secret = \"important message\"`, it seems `secret_key` is used to encrypt this message, and then `secret_key` itself is encrypted by `authorized_keys`.
  However, the `new/3` implementation has `secret: secret` and encrypts `secret_key` with `public_key`.
  This suggests `secret_key` is what is being shared to potentially decrypt the `secret` field later.
  I will assume the `secret_key` is the item being encrypted and shared, and `secret` is some associated data.
  If `secret` itself is to be encrypted by `secret_key`, that step is currently missing from `new/3`.

  For now, documentation will reflect that `secret_key` is encrypted for each `authorized_key`.
  The `secret` field will be documented as the data associated with this ownership, which might be plaintext or pre-encrypted.
  """

  alias ArchethicClient.Crypto
  alias ArchethicClient.Utils.VarInt

  defstruct authorized_keys: %{}, secret: ""

  @type t :: %__MODULE__{
          secret: binary(),
          authorized_keys: %{(public_key :: Crypto.key()) => encrypted_key :: binary()}
        }

  @doc """
  Create a new ownership by passing its secret, a list of authorized public keys,
  and a secret key.

  The `secret_key` is encrypted for each public key in `authorized_keys` using ECIES.
  The provided `secret` is stored directly. If this `secret` needs to be encrypted
  by the `secret_key`, that must be done by the caller before invoking this function.

  ## Examples

      iex> secret_data = \"important message\" # This is the data associated with the ownership
      ...> secret_encryption_key = :crypto.strong_rand_bytes(32) # This key will be encrypted and shared
      ...> {pub, _pv} = ArchethicClient.Crypto.generate_deterministic_keypair(\"seed\")
      ...> ownership = ArchethicClient.TransactionData.Ownership.new(secret_data, [pub], secret_encryption_key)
      ...> authorized_keys_map = ownership.authorized_keys
      ...> {retrieved_pub, _encrypted_secret_key} = Enum.at(Map.to_list(authorized_keys_map), 0)
      ...> retrieved_pub == pub
      true
  """
  @spec new(secret :: binary(), authorized_keys :: list(Crypto.key()), secret_key :: binary()) :: t()
  def new(secret, authorized_keys, secret_key \\ :crypto.strong_rand_bytes(32)) do
    %__MODULE__{
      secret: secret,
      authorized_keys:
        Map.new(authorized_keys, fn public_key -> {public_key, Crypto.ec_encrypt(secret_key, public_key)} end)
    }
  end

  @doc """
  Serialize an ownership

  ## Examples

      iex> %ArchethicClient.TransactionData.Ownership{
      ...>   secret: <<205, 124, 251, 211, 28, 69, 249, 1, 58, 108, 16, 35, 23, 206, 198, 202>>,
      ...>   authorized_keys: %{
      ...>     <<0, 0, 229, 188, 159, 80, 100, 5, 54, 152, 137, 201, 204, 24, 22, 125, 76, 29, 83,
      ...>       14, 154, 60, 66, 69, 121, 97, 40, 215, 226, 204, 133, 54, 187,
      ...>       9>> =>
      ...>       <<139, 100, 20, 32, 187, 77, 56, 30, 116, 207, 34, 95, 157, 128, 208, 115, 113,
      ...>         177, 45, 9, 93, 107, 90, 254, 173, 71, 60, 181, 113, 247, 75, 151, 127, 41, 7,
      ...>         233, 227, 98, 209, 211, 97, 117, 68, 101, 59, 121, 214, 105, 225, 218, 91, 92,
      ...>         212, 162, 48, 18, 15, 181, 70, 103, 32, 141, 4, 64, 107, 93, 117, 188, 244, 7,
      ...>         224, 214, 225, 146, 44, 83, 111, 34, 239, 99>>
      ...>   }
      ...> }
      ...> |> ArchethicClient.TransactionData.Ownership.serialize()
      <<0, 0, 0, 16, 205, 124, 251, 211, 28, 69, 249, 1, 58, 108, 16, 35, 23, 206, 198, 202, 1, 1,
        0, 0, 229, 188, 159, 80, 100, 5, 54, 152, 137, 201, 204, 24, 22, 125, 76, 29, 83, 14, 154,
        60, 66, 69, 121, 97, 40, 215, 226, 204, 133, 54, 187, 9, 139, 100, 20, 32, 187, 77, 56, 30,
        116, 207, 34, 95, 157, 128, 208, 115, 113, 177, 45, 9, 93, 107, 90, 254, 173, 71, 60, 181,
        113, 247, 75, 151, 127, 41, 7, 233, 227, 98, 209, 211, 97, 117, 68, 101, 59, 121, 214, 105,
        225, 218, 91, 92, 212, 162, 48, 18, 15, 181, 70, 103, 32, 141, 4, 64, 107, 93, 117, 188,
        244, 7, 224, 214, 225, 146, 44, 83, 111, 34, 239, 99>>
  """
  @spec serialize(ownership :: t()) :: binary()
  def serialize(%__MODULE__{secret: secret, authorized_keys: authorized_keys}) do
    authorized_keys_bin =
      authorized_keys
      |> Enum.map(fn {public_key, encrypted_key} -> <<public_key::binary, encrypted_key::binary>> end)
      |> :erlang.list_to_binary()

    serialized_length = VarInt.from_value(map_size(authorized_keys))

    <<byte_size(secret)::32, secret::binary, serialized_length::binary, authorized_keys_bin::binary>>
  end

  @spec to_map(ownership :: t()) :: map()
  def to_map(%__MODULE__{secret: secret, authorized_keys: authorized_keys}) do
    %{
      secret: Base.encode16(secret),
      authorizedKeys: Map.new(authorized_keys, fn {pub, key} -> {Base.encode16(pub), Base.encode16(key)} end)
    }
  end
end
