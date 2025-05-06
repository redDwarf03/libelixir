defmodule ArchethicClient.TransactionData.Ledger.UCOLedger do
  @moduledoc """
  Represents ledger movements specifically for UCO, the native currency of the Archethic network.

  This struct holds a list of `ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer`
  records, detailing each UCO movement within a transaction.
  It provides functions for serialization and map conversion of these UCO ledger entries.
  """
  alias __MODULE__.Transfer
  alias ArchethicClient.Utils.VarInt

  defstruct transfers: []

  @typedoc """
  UCO movement is composed from:
  - Transfers: List of UCO transfers
  """
  @type t :: %__MODULE__{
          transfers: list(Transfer.t())
        }

  @doc """
  Serialize a UCO ledger into binary format

  ## Examples

      iex> %UCOLedger{
      ...>   transfers: [
      ...>     %Transfer{
      ...>       to:
      ...>         <<0, 0, 59, 140, 2, 130, 52, 88, 206, 176, 29, 10, 173, 95, 179, 27, 166, 66, 52,
      ...>           165, 11, 146, 194, 246, 89, 73, 85, 202, 120, 242, 136, 136, 63, 53>>,
      ...>       amount: 1_050_000_000
      ...>     }
      ...>   ]
      ...> }
      ...> |> UCOLedger.serialize()
      <<1, 1, 0, 0, 59, 140, 2, 130, 52, 88, 206, 176, 29, 10, 173, 95, 179, 27, 166, 66, 52, 165,
        11, 146, 194, 246, 89, 73, 85, 202, 120, 242, 136, 136, 63, 53, 0, 0, 0, 0, 62, 149, 186,
        128>>
  """
  @spec serialize(uco_ledger :: t()) :: binary()
  def serialize(%__MODULE__{transfers: transfers}) do
    transfers_bin = transfers |> Enum.map(&Transfer.serialize/1) |> :erlang.list_to_binary()

    encoded_transfer = VarInt.from_value(length(transfers))
    <<encoded_transfer::binary, transfers_bin::binary>>
  end

  @spec to_map(uco_ledger :: t()) :: map()
  def to_map(%__MODULE__{transfers: transfers}) do
    %{transfers: Enum.map(transfers, &Transfer.to_map/1)}
  end
end
