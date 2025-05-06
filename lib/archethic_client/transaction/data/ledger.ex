defmodule ArchethicClient.TransactionData.Ledger do
  @moduledoc """
  Represents ledger movements within a transaction, encompassing both UCO (native currency)
  and token transfers.

  This struct aggregates `UCOLedger` and `TokenLedger` data, providing a unified view
  of all asset movements in a transaction. It includes functions for serialization
  and map conversion.
  """

  alias __MODULE__.TokenLedger
  alias __MODULE__.UCOLedger

  defstruct uco: %UCOLedger{}, token: %TokenLedger{}

  @typedoc """
  Ledger movements are composed from:
  - UCO: movements of UCO
  """
  @type t :: %__MODULE__{
          uco: UCOLedger.t(),
          token: TokenLedger.t()
        }

  @doc """
  Serialize the ledger into binary format

  ## Examples

      iex> %Ledger{
      ...>   uco: %UCOLedger{
      ...>     transfers: [
      ...>       %UCOLedger.Transfer{
      ...>         to:
      ...>           <<0, 0, 59, 140, 2, 130, 52, 88, 206, 176, 29, 10, 173, 95, 179, 27, 166, 66,
      ...>             52, 165, 11, 146, 194, 246, 89, 73, 85, 202, 120, 242, 136, 136, 63, 53>>,
      ...>         amount: 1_050_000_000
      ...>       }
      ...>     ]
      ...>   },
      ...>   token: %TokenLedger{
      ...>     transfers: [
      ...>       %TokenLedger.Transfer{
      ...>         token_address:
      ...>           <<0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71,
      ...>             140, 74, 197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175>>,
      ...>         to:
      ...>           <<0, 0, 59, 140, 2, 130, 52, 88, 206, 176, 29, 10, 173, 95, 179, 27, 166, 66,
      ...>             52, 165, 11, 146, 194, 246, 89, 73, 85, 202, 120, 242, 136, 136, 63, 53>>,
      ...>         amount: 1_050_000_000,
      ...>         token_id: 0
      ...>       }
      ...>     ]
      ...>   }
      ...> }
      ...> |> Ledger.serialize()
      <<1, 1, 0, 0, 59, 140, 2, 130, 52, 88, 206, 176, 29, 10, 173, 95, 179, 27, 166, 66, 52, 165,
        11, 146, 194, 246, 89, 73, 85, 202, 120, 242, 136, 136, 63, 53, 0, 0, 0, 0, 62, 149, 186,
        128, 1, 1, 0, 0, 49, 101, 72, 154, 152, 3, 174, 47, 2, 35, 7, 92, 122, 206, 185, 71, 140,
        74, 197, 46, 99, 117, 89, 96, 100, 20, 0, 34, 181, 215, 143, 175, 0, 0, 59, 140, 2, 130, 52,
        88, 206, 176, 29, 10, 173, 95, 179, 27, 166, 66, 52, 165, 11, 146, 194, 246, 89, 73, 85,
        202, 120, 242, 136, 136, 63, 53, 0, 0, 0, 0, 62, 149, 186, 128, 1, 0>>
  """
  @spec serialize(transaction_ledger :: t()) :: binary()
  def serialize(%__MODULE__{uco: uco_ledger, token: token_ledger}),
    do: <<UCOLedger.serialize(uco_ledger)::binary, TokenLedger.serialize(token_ledger)::binary>>

  @doc """
  Converts a `Ledger` struct or `nil` into a map representation.

  - If the input `ledger` is a `Ledger` struct, it converts the nested `uco` and `token`
    ledgers to their map representations using their respective `to_map` functions.
  - If `nil` is provided, it returns a map where `uco` and `token` fields are the results
    of calling `to_map` on newly created empty `UCOLedger` and `TokenLedger` structs,
    effectively providing a default empty map structure for the ledger.
  """
  @spec to_map(ledger :: t() | nil) :: map()
  def to_map(nil) do
    %{
      uco: UCOLedger.to_map(%UCOLedger{}),
      token: TokenLedger.to_map(%TokenLedger{})
    }
  end

  def to_map(%__MODULE__{uco: uco, token: token}) do
    %{
      uco: UCOLedger.to_map(uco),
      token: TokenLedger.to_map(token)
    }
  end
end
