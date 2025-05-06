defmodule ArchethicClient.TransactionData.Ledger.TokenLedger do
  @moduledoc """
  Represents ledger movements specifically for fungible or non-fungible tokens.

  This struct holds a list of `ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer`
  records, detailing each token movement within a transaction.
  It provides functions for serialization and map conversion of these token ledger entries.
  """
  alias __MODULE__.Transfer
  alias ArchethicClient.Utils.VarInt

  defstruct transfers: []

  @typedoc """
  Token ledger movement is composed from:
  - `transfers`: A list of `ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer.t()` records.
  """
  @type t :: %__MODULE__{
          transfers: list(Transfer.t())
        }

  @doc """
  Serialize a Token ledger into binary format

  ## Examples

      iex> %TokenLedger{
      ...>   transfers: [
      ...>     %Transfer{
      ...>       token_address:
      ...>         <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140,
      ...>           74, 197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>,
      ...>       to:
      ...>         <<0, 0, 59, 140, 2, 130, 52, 88, 206, 176, 29, 10, 173, 95, 179, 27, 166, 66, 52,
      ...>           165, 11, 146, 194, 246, 89, 73, 85, 202, 120, 242, 136, 136, 63, 53>>,
      ...>       amount: 1_050_000_000,
      ...>       token_id: 0
      ...>     }
      ...>   ]
      ...> }
      ...> |> TokenLedger.serialize()
      <<1, 1, 0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140, 74,
        197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175, 0, 0, 59, 140, 2, 130, 52, 88,
        206, 176, 29, 10, 173, 95, 179, 27, 166, 66, 52, 165, 11, 146, 194, 246, 89, 73, 85, 202,
        120, 242, 136, 136, 63, 53, 0, 0, 0, 0, 62, 149, 186, 128, 1, 0>>
  """
  @spec serialize(token_ledger :: t()) :: binary()
  def serialize(%__MODULE__{transfers: transfers}) do
    transfers_bin = transfers |> Enum.map(&Transfer.serialize/1) |> :erlang.list_to_binary()

    encoded_transfer = transfers |> length() |> VarInt.from_value()
    <<encoded_transfer::binary, transfers_bin::binary>>
  end

  @spec to_map(token_ledger :: t()) :: map()
  def to_map(%__MODULE__{transfers: transfers}), do: %{transfers: Enum.map(transfers, &Transfer.to_map/1)}
end
