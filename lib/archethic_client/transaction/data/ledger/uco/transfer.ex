defmodule ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer do
  @moduledoc """
  Represents a single transfer of UCO (the native currency) within a transaction.

  Each UCO transfer specifies:
  - `to`: The recipient address for the UCO.
  - `amount`: The quantity of UCO to transfer (in its smallest unit, UCOents, where 1 UCO = 10^8 UCOents).

  This module provides functions for serializing UCO transfer data and converting it to a map.
  """

  alias ArchethicClient.Crypto

  defstruct [:to, :amount]

  @typedoc """
  A UCO transfer is composed of:
  - `to`: The recipient `Crypto.address/0` of the UCO.
  - `amount`: The non-negative integer amount of UCO to transfer (in the smallest unit, 10^-8).
  """
  @type t :: %__MODULE__{
          to: Crypto.address(),
          amount: non_neg_integer()
        }

  @doc """
  Serialize UCO transfer into binary format

  ## Examples

      iex> %ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer{
      ...>   to:
      ...>     <<0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117, 85,
      ...>       106, 43, 26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14>>,
      ...>   amount: 1_050_000_000
      ...> }
      ...> |> ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer.serialize()
      <<0, 104, 134, 142, 120, 40, 59, 99, 108, 63, 166, 143, 250, 93, 186, 216, 117, 85, 106, 43,
        26, 120, 35, 44, 137, 243, 184, 160, 251, 223, 0, 93, 14, 0, 0, 0, 0, 62, 149, 186, 128>>
  """
  def serialize(%__MODULE__{to: to, amount: amount}), do: <<to::binary, amount::64>>

  @doc """
  Converts a UCO `Transfer` struct to a map representation.

  The `to` address is Base16 encoded in the resulting map.

  ## Examples

      iex> transfer_data = %ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer{
      ...>   to: <<0, 1, 2, 3>>,
      ...>   amount: 100
      ...> }
      ...> ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer.to_map(transfer_data)
      %{to: "00010203", amount: 100}
  """
  @spec to_map(uco_transfer :: t()) :: map()
  def to_map(%__MODULE__{to: to, amount: amount}), do: %{to: Base.encode16(to), amount: amount}
end
