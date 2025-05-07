defmodule ArchethicClientTest do
  use ExUnit.Case

  doctest ArchethicClient
  doctest ArchethicClient.Utils
  doctest ArchethicClient.Utils.VarInt
  doctest ArchethicClient.Transaction
  doctest ArchethicClient.TransactionData.Ownership
  doctest ArchethicClient.TransactionData.Ledger.TokenLedger.Transfer
  doctest ArchethicClient.TransactionData.Ledger.UCOLedger.Transfer

end
