defmodule ArchethicClient.Test.Behaviors do
  @moduledoc """
  Defines behaviors for use in testing with Mox.

  This module is loaded early in the compilation process when testing
  to ensure behaviors are defined before modules implement them.
  """

  defmodule API do
    @moduledoc """
    Behavior definition for ArchethicClient.API to enable mocking with Mox.
    """
    @callback request(ArchethicClient.Request.t(), keyword()) ::
                {:ok, term()} | {:error, reason :: Exception.t()}
    @callback request!(ArchethicClient.Request.t(), keyword()) :: term()
    @callback subscribe(ArchethicClient.Request.t(), keyword()) ::
                {:ok, subscription_ref :: reference()} | {:error, Exception.t()}
    @callback batch_requests(list(ArchethicClient.Request.t()), keyword()) ::
                list({:ok, term()} | {:error, Exception.t()})
    @callback batch_requests!(list(ArchethicClient.Request.t()), keyword()) :: list(term())
  end

  defmodule RequestHelper do
    @moduledoc """
    Behavior definition for ArchethicClient.RequestHelper to enable mocking with Mox.
    """
    @callback get_balance(ArchethicClient.Crypto.hex_address()) :: ArchethicClient.Request.t()
    @callback contract_function_call(
                ArchethicClient.Crypto.hex_address(),
                String.t(),
                list(),
                keyword()
              ) :: ArchethicClient.Request.t()
    @callback send_transaction(ArchethicClient.Transaction.t()) :: ArchethicClient.Request.t()
    @callback subscribe_transaction_confirmed(ArchethicClient.Crypto.hex_address()) :: ArchethicClient.Request.t()
    @callback subscribe_transaction_error(ArchethicClient.Crypto.hex_address()) :: ArchethicClient.Request.t()
  end
end
