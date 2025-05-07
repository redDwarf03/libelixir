defmodule ArchethicClient.Transaction do
  @moduledoc """
  Defines the structure and functions for creating Archethic transactions.

  A transaction is the fundamental unit of change on the Archethic network.
  This module provides tools to build various transaction types, sign them,
  and serialize them for network transmission.
  """

  alias ArchethicClient.API
  alias ArchethicClient.Crypto
  alias ArchethicClient.TransactionData

  @type serialization_mode :: :compact | :extended

  @version 1

  defstruct [
    :address,
    :type,
    :previous_public_key,
    :previous_signature,
    :origin_signature,
    data: %TransactionData{},
    version: @version
  ]

  @typedoc """
  Represent a transaction in pending validation
  - Address: hash of the new generated public key for the given transaction
  - Type: transaction type
  - Data: transaction data zone (identity, keychain, smart contract, etc.)
  - Previous signature: signature from the previous public key
  - Previous public key: previous generated public key matching the previous signature
  - Origin signature: signature from the device which originated the transaction (used in the Proof of work)
  - Version: version of the transaction (used for backward compatiblity)
  """
  @type t() :: %__MODULE__{
          address: Crypto.address(),
          type: transaction_type(),
          data: TransactionData.t(),
          previous_public_key: Crypto.key(),
          previous_signature: binary(),
          origin_signature: binary(),
          version: pos_integer()
        }

  @typedoc """
  Supported transaction types
  """
  @type transaction_type :: :keychain | :keychain_access | :transfer | :token | :hosting | :data | :contract

  @type build_options :: [
          api_opts: API.request_opts(),
          index: non_neg_integer(),
          derivation_opts: Crypto.derivation_options(),
          origin_private_key: Crypto.key()
        ]

  @transaction_types [:keychain, :keychain_access, :transfer, :token, :hosting, :data, :contract]
  @origin_private_key Base.decode16!("01019280BDB84B8F8AEDBA205FE3552689964A5626EE2C60AA10E3BF22A91A036009")

  @doc """
  Build a new transaction
  """
  @spec build(data :: TransactionData.t(), type :: transaction_type(), seed :: binary(), opts :: build_options()) ::
          t()
  def build(%TransactionData{} = data, type, seed, opts \\ [])
      when type in @transaction_types and is_binary(seed) and is_list(opts) do
    Keyword.validate!(opts, [:api_opts, :derivation_opt, :index, :origin_private_key])
    {api_opts, opts} = Keyword.pop(opts, :api_opts, [])
    {derivation_opts, opts} = Keyword.pop(opts, :derivation_opts, [])
    {origin_private_key, opts} = Keyword.pop(opts, :origin_private_key, @origin_private_key)

    index =
      Keyword.get_lazy(opts, :index, fn ->
        seed
        |> Crypto.derive_address(0, derivation_opts)
        |> Base.encode16()
        |> ArchethicClient.get_chain_index!(api_opts)
      end)

    tx_address = Crypto.derive_address(seed, index + 1, derivation_opts)
    {previous_public_key, previous_private_key} = Crypto.derive_keypair(seed, index, derivation_opts)
    previous_signature = data |> previous_signature_payload(type, tx_address) |> Crypto.sign(previous_private_key)

    origin_signature =
      data
      |> origin_signature_payload(type, tx_address, previous_public_key, previous_signature)
      |> Crypto.sign(origin_private_key)

    %__MODULE__{
      address: tx_address,
      type: type,
      data: data,
      previous_public_key: previous_public_key,
      previous_signature: previous_signature,
      origin_signature: origin_signature,
      version: @version
    }
  end

  @doc """
  Generates the binary payload that needs to be signed by the previous private key.

  This payload includes the transaction version, the new transaction address,
  the serialized transaction type, and the serialized transaction data.
  """
  @spec previous_signature_payload(
          data :: TransactionData.t(),
          type :: transaction_type(),
          address :: Crypto.address()
        ) :: binary()
  def previous_signature_payload(data, type, address),
    do: <<@version::32, address::binary, serialize_type(type)::8, TransactionData.serialize(data)::binary>>

  @doc """
  Return the payload for the origin signature
  """
  @spec origin_signature_payload(
          data :: TransactionData.t(),
          type :: transaction_type(),
          address :: Crypto.address(),
          previous_public_key :: Crypto.key(),
          previous_signature :: binary()
        ) :: binary()
  def origin_signature_payload(data, type, address, previous_public_key, previous_signature) do
    <<@version::32, address::binary, serialize_type(type)::8, TransactionData.serialize(data)::binary,
      previous_public_key::binary, byte_size(previous_signature)::8, previous_signature::binary>>
  end

  @doc """
  Converts a transaction struct into a map representation.

  The binary fields like address, public key, and signatures are hex-encoded.
  The transaction type atom is converted to a string.
  """
  @spec to_map(transaction :: t()) :: map()
  def to_map(%__MODULE__{} = tx) do
    %{
      version: tx.version,
      address: Base.encode16(tx.address),
      type: Atom.to_string(tx.type),
      data: TransactionData.to_map(tx.data),
      previousPublicKey: Base.encode16(tx.previous_public_key),
      previousSignature: Base.encode16(tx.previous_signature),
      originSignature: Base.encode16(tx.origin_signature)
    }
  end

  # Serializes the :keychain transaction type atom to its integer ID (255).
  defp serialize_type(:keychain), do: 255
  # Serializes the :keychain_access transaction type atom to its integer ID (254).
  defp serialize_type(:keychain_access), do: 254
  # Serializes the :transfer transaction type atom to its integer ID (253).
  defp serialize_type(:transfer), do: 253
  # Serializes the :hosting transaction type atom to its integer ID (252).
  defp serialize_type(:hosting), do: 252
  # Serializes the :token transaction type atom to its integer ID (251).
  defp serialize_type(:token), do: 251
  # Serializes the :data transaction type atom to its integer ID (250).
  defp serialize_type(:data), do: 250
  # Serializes the :contract transaction type atom to its integer ID (249).
  defp serialize_type(:contract), do: 249
end
