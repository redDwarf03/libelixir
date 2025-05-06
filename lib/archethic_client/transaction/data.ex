defmodule ArchethicClient.TransactionData do
  @moduledoc """
  Defines the structure and functions for managing the data payload of an Archethic transaction.

  The `TransactionData` struct can contain various types of information, including:
  - `recipients`: For smart contract interactions, specifying target addresses, actions, and arguments.
  - `ledger`: Operations related to UCO (native currency) or other tokens (transfers).
  - `contract`: The definition of a smart contract if the transaction deploys or modifies one.
  - `ownerships`: Proofs of secret ownership, authorizing keys for access.
  - `content`: Arbitrary binary data that can be stored on the blockchain.

  This module provides functions to build up the transaction data, serialize it for inclusion
  in a transaction, and convert it to a map representation.
  """

  alias __MODULE__.Contract
  alias __MODULE__.Ledger
  alias __MODULE__.Ledger.TokenLedger.Transfer, as: TokenTransfer
  alias __MODULE__.Ledger.UCOLedger.Transfer, as: UCOTransfer
  alias __MODULE__.Ownership
  alias __MODULE__.Recipient
  alias ArchethicClient.Crypto
  alias ArchethicClient.Utils.VarInt

  defstruct recipients: [], ledger: %Ledger{}, ownerships: [], content: "", contract: nil

  @typedoc """
  Transaction data is composed from:
  - Recipients: list of recipients for smart contract interactions
  - Ledger: Movement operations on UCO TOKEN or Stock ledger
  - Contract: Contains the smart contract definition
  - Ownerships: List of the authorizations and delegations to proof ownership of secrets
  - Content: Free content to store any data as binary
  """
  @type t :: %__MODULE__{
          recipients: list(Recipient.t()),
          ledger: Ledger.t(),
          contract: nil | Contract.t(),
          ownerships: list(Ownership.t()),
          content: binary()
        }

  @doc """
  Set the content of a transaction
  """
  @spec set_content(data :: t(), content :: binary()) :: t()
  def set_content(%__MODULE__{} = data, content) when is_binary(content), do: %__MODULE__{data | content: content}

  @doc """
  Add an ownership to a transaction
  This function keeps the order of the added ownerships
  """
  @spec add_ownership(
          data :: t(),
          secret :: binary(),
          authorized_keys :: list(Crypto.key()),
          secret_key :: binary()
        ) ::
          t()
  def add_ownership(
        %__MODULE__{ownerships: ownerships} = data,
        secret,
        authorized_keys,
        secret_key \\ :crypto.strong_rand_bytes(32)
      )
      when is_binary(secret) and is_list(authorized_keys) and is_binary(secret_key) do
    ownership = Ownership.new(secret, authorized_keys, secret_key)

    %__MODULE__{data | ownerships: ownerships ++ [ownership]}
  end

  @doc """
  Add a UCO transfer to a transaction
  """
  @spec add_uco_transfer(data :: t(), to :: Crypto.address(), amount :: integer()) :: t()
  def add_uco_transfer(%__MODULE__{} = data, to, amount) when is_binary(to) and is_integer(amount) do
    transfer = %UCOTransfer{to: to, amount: amount}
    update_in(data, [Access.key!(:ledger), Access.key!(:uco), Access.key!(:transfers)], &[transfer | &1])
  end

  @doc """
  Add a token transfer to a transaction
  """
  @spec add_token_transfer(
          data :: t(),
          to :: Crypto.address(),
          amount :: integer(),
          token_address :: Crypto.address(),
          token_id :: non_neg_integer()
        ) :: t()
  def add_token_transfer(%__MODULE__{} = data, to, amount, token_address, token_id \\ 0)
      when is_binary(to) and is_integer(amount) and is_binary(token_address) and is_integer(token_id) do
    transfer = %TokenTransfer{to: to, amount: amount, token_address: token_address, token_id: token_id}
    update_in(data, [Access.key!(:ledger), Access.key!(:token), Access.key!(:transfers)], &[transfer | &1])
  end

  @doc """
  Add a recipient to a transaction
  """
  @spec add_recipient(data :: t(), to :: Crypto.address(), action :: String.t(), args :: list()) :: t()
  def add_recipient(%__MODULE__{recipients: recipients} = data, to, action, args \\ [])
      when is_binary(to) and is_binary(action) and is_list(args) do
    recipient = %Recipient{address: to, action: action, args: args}
    %__MODULE__{data | recipients: [recipient | recipients]}
  end

  @doc """
  Serialize transaction data into binary format
  """
  @spec serialize(tx_data :: t()) :: binary()
  def serialize(%__MODULE__{
        content: content,
        contract: contract,
        ownerships: ownerships,
        ledger: ledger,
        recipients: recipients
      }) do
    ownerships_bin = ownerships |> Enum.map(&Ownership.serialize/1) |> :erlang.list_to_binary()
    recipients_bin = recipients |> Enum.map(&Recipient.serialize/1) |> :erlang.list_to_binary()
    encoded_ownership_len = ownerships |> length() |> VarInt.from_value()
    encoded_recipients_len = recipients |> length() |> VarInt.from_value()
    contract_bin = serialize_contract_field(contract)

    <<contract_bin::bitstring, byte_size(content)::32, content::binary,
    encoded_ownership_len::binary, ownerships_bin::binary,
    Ledger.serialize(ledger)::binary, encoded_recipients_len::binary,
    recipients_bin::bitstring>>
  end

  # Serializes the contract field.
  # If the contract is nil, it writes a 0 byte (false flag).
  # If a contract exists, it writes a 1 byte (true flag) followed by the serialized contract.
  defp serialize_contract_field(nil), do: <<0::8>>
  defp serialize_contract_field(%Contract{} = contract) do
    <<1::8, Contract.serialize(contract, 0)::bitstring>>
  end

  @doc """
  Converts `TransactionData` to a map representation.
  If `nil` is provided, returns a map with default empty values.
  """
  @spec to_map(t() | nil) :: map()
  def to_map(nil) do
    %{
      content: "",
      contract: nil,
      ledger: Ledger.to_map(nil),
      ownerships: [],
      recipients: []
    }
  end

  @spec to_map(data :: t()) :: map()
  def to_map(%__MODULE__{content: content, ledger: ledger, ownerships: ownerships, recipients: recipients, contract: contract}) do
    %{
      content: content,
      contract: Contract.to_map(contract),
      ledger: Ledger.to_map(ledger),
      ownerships: Enum.map(ownerships, &Ownership.to_map/1),
      recipients: Enum.map(recipients, &Recipient.to_map/1)
    }
  end
end
