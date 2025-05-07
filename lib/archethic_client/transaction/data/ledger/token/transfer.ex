defmodule ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer do
  @moduledoc """
  Represents a single transfer of a fungible or non-fungible token within a transaction.

  Each token transfer specifies:
  - `token_address`: The address of the token contract.
  - `to`: The recipient address for the token.
  - `amount`: The quantity of the token to transfer (in its smallest unit, e.g., 10^-8 for tokens with 8 decimal places).
  - `token_id`: For non-fungible tokens (NFTs) or token collections, this identifies the specific token instance. Defaults to 0.
  - `conditions`: (Currently not utilized in serialization or map conversion) A list of addresses to which the token can be further transferred or used.

  This module provides functions for serializing token transfer data and converting it to a map.
  """
  alias ArchethicClient.Utils.VarInt

  defstruct [:to, :amount, :token_address, conditions: [], token_id: 0]

  @typedoc """
  Transfer is composed from:
  - token_address: Token address
  - to: receiver address of the asset
  - amount: specify the number of Token to transfer to the recipients (in the smallest unit 10^-8)
  - conditions: specify to which address the Token can be used
  - token_id: To uniquely identify a token from a set a of token(token collection)
  """
  @type t :: %__MODULE__{
          token_address: binary(),
          to: binary(),
          amount: non_neg_integer(),
          conditions: list(binary()),
          token_id: non_neg_integer()
        }

  @doc """
  Serialize Token transfer into binary format

  The `conditions` field is currently not included in the serialization.

  ## Examples

      iex> %ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer{
      ...>   token_address:
      ...>     <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
      ...>       197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>,
      ...>   to:
      ...>     <<0, 0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117,
      ...>       85, 106, 43, 26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14>>,
      ...>   amount: 1_050_000_000,
      ...>   token_id: 0
      ...> }
      ...> |> ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer.serialize()
      <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74, 197, 46,
        99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175, 0, 0, 104, 134, 142, 120, 40, 59, 99,
        108, 63, 166, 143, 250, 93, 186, 216, 117, 85, 106, 43, 26, 120, 35, 44, 137, 243, 184, 160,
        251, 223, 0, 93, 14, 0, 0, 0, 0, 62, 149, 186, 128, 1, 0>>
  """
  @spec serialize(token_transfer :: t()) :: bitstring()
  def serialize(%__MODULE__{token_address: token, to: to, amount: amount, token_id: token_id}),
    do: <<token::binary, to::binary, amount::64, VarInt.from_value(token_id)::binary>>

  @doc """
  Converts a token `Transfer` struct to a map representation.

  The `token_address` and `to` fields are Base16 encoded.
  Map keys are camelCased (e.g., `tokenAddress`, `tokenId`).
  The `conditions` field is currently not included in the resulting map.

  ## Examples

        iex> %ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer{
        ...>   token_address:
        ...>     <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140,
        ...>       74, 197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>,
        ...>   to:
        ...>     <<0, 0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117,
        ...>       85, 106, 43, 26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14>>,
        ...>   amount: 1_050_000_000,
        ...>   token_id: 0
        ...> }
        ...> |> ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer.to_map()
        %{
          tokenAddress: "00003165489A9803AE2F0223075C7ACEB9478C4AC52E6375596064140022B5D78FAF",
          to: "000068868E78283B636C3FA68FFA5DBAD875556A2B1A78232C89F3B8A0FBDF005D0E",
          amount: 1_050_000_000,
          tokenId: 0
        }
  """
  @spec to_map(token_transfer :: t()) :: map()
  def to_map(%__MODULE__{token_address: token_address, to: to, amount: amount, token_id: token_id}) do
    %{
      tokenAddress: Base.encode16(token_address),
      to: Base.encode16(to),
      amount: amount,
      tokenId: token_id
    }
  end
end
