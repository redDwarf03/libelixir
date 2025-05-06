defmodule ArchethicClient do
  @moduledoc """
  The main module for the ArchethicClient library.

  This module provides the primary API for interacting with the Archethic
  blockchain. It offers functions to send requests, manage transactions,
  query balances, and interact with smart contracts.
  """

  alias ArchethicClient.API
  alias ArchethicClient.Crypto
  alias ArchethicClient.Graphql
  alias ArchethicClient.GraphqlError
  alias ArchethicClient.Request
  alias ArchethicClient.RequestHelper
  alias ArchethicClient.Subscription
  alias ArchethicClient.TaskSupervisor
  alias ArchethicClient.Transaction
  alias ArchethicClient.ValidationError

  @tx_validation_timeout 60_000

  @doc """
  Send a request to Archethic network
  """
  @spec request(request :: Request.t(), opts :: API.request_opts()) :: {:ok, term()} | {:error, Exception.t()}
  defdelegate request(request, opts \\ []), to: API

  @doc """
  Same as request/2 but raise on error
  """
  @spec request!(request :: Request.t(), opts :: API.request_opts()) :: term()
  defdelegate request!(request, opts \\ []), to: API

  @doc """
  Batch multiple Request into a single request per Request type
  It keeps the same order as the request list provided
  """
  @spec batch_requests(requests :: list(Request.t()), opts :: API.request_opts()) ::
          list({:ok, term()} | {:error, Exception.t()})
  defdelegate batch_requests(requests, opts \\ []), to: API

  @doc """
  Same as batch_requests/2 but raise on error
  """
  @spec batch_requests!(requests :: list(Request.t()), opts :: API.request_opts()) :: list(term())
  defdelegate batch_requests!(requests, opts \\ []), to: API

  @doc """
  Returns the balance of a genesis address
  Shortcut of `address |> RequestHelper.get_balance() |> ArchethicClient.request()`
  """
  @spec get_balance(genesis_address :: Crypto.hex_address(), opts :: API.request_opts()) ::
          {:ok, map()} | {:error, Exception.t()}
  def get_balance(genesis_address, opts \\ []), do: genesis_address |> RequestHelper.get_balance() |> request(opts)

  @doc """
  Same as `get_balance/2` but raise on error
  """
  @spec get_balance!(genesis_address :: Crypto.hex_address(), opts :: API.request_opts()) :: map()
  def get_balance!(genesis_address, opts \\ []), do: genesis_address |> RequestHelper.get_balance() |> request!(opts)

  @doc """
  Call a contract public function
  Shortcut of `address |> RequestHelper.contract_function_call("function") |> ArchethicClient.request()`
  """
  @spec call_contract_function(
          contract_address :: Crypto.hex_address(),
          function :: String.t(),
          args :: list(),
          opts :: API.request_opts()
        ) :: {:ok, term()} | {:error, Exception.t()}
  def call_contract_function(contract_address, function, args \\ [], opts \\ []),
    do: contract_address |> RequestHelper.contract_function_call(function, args) |> request(opts)

  @doc """
  Same as `call_contract_function/4` but raise on error
  """
  @spec call_contract_function!(
          contract_address :: Crypto.hex_address(),
          function :: String.t(),
          args :: list(),
          opts :: API.request_opts()
        ) :: term()
  def call_contract_function!(contract_address, function, args \\ [], opts \\ []),
    do: contract_address |> RequestHelper.contract_function_call(function, args) |> request!(opts)

  @doc """
  Returns the index of a chain
  """
  @spec get_chain_index(address :: Crypto.hex_address(), opts :: API.request_opts()) ::
          {:ok, non_neg_integer()} | {:error, Exception.t()}
  def get_chain_index(address, opts \\ []) do
    graphql_request = %Graphql{name: "lastTransaction", args: [address: address], fields: [:chainLength]}

    case request(graphql_request, opts) do
      {:ok, %{"chainLength" => index}} -> {:ok, index}
      {:error, %GraphqlError{message: "transaction_not_exists"}} -> {:ok, 0}
      er -> er
    end
  end

  @doc """
  Same as `get_chain_index/2` but raise on error
  """
  @spec get_chain_index!(address :: Crypto.hex_address(), opts :: API.request_opts()) :: non_neg_integer()
  def get_chain_index!(address, opts \\ []) do
    case get_chain_index(address, opts) do
      {:ok, index} -> index
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Send a transaction to Archethic network
  """
  @spec send_transaction(transaction :: Transaction.t(), opts :: API.request_opts()) ::
          :ok | {:error, Exception.t() | :timeout}
  def send_transaction(%Transaction{address: address} = transaction, opts \\ []) do
    address_hex = Base.encode16(address)
    confirmed_sub = RequestHelper.subscribe_transaction_confirmed(address_hex)
    error_sub = RequestHelper.subscribe_transaction_error(address_hex)

    # Runs in a task to close web socket after transaction validation
    task =
      Task.Supervisor.async_nolink(TaskSupervisor, fn ->
        opts = Keyword.put(opts, :parent, self())

        subscriptions =
          TaskSupervisor
          |> Task.Supervisor.async_stream_nolink([confirmed_sub, error_sub], &API.subscribe(&1, opts),
            on_timeout: :kill_task
          )
          |> Enum.map(fn
            {:ok, res} -> res
            {:exit, reason} -> {:error, reason}
          end)

        case subscriptions do
          [{:ok, confirmed_ref}, {:ok, error_ref}] ->
            send_tx_and_await_validation(transaction, opts, confirmed_ref, error_ref)

          _ ->
            Enum.find(subscriptions, &match?({:error, _}, &1))
        end
      end)

    case Task.yield(task, @tx_validation_timeout * 2) || Task.shutdown(task, :brutal_kill) do
      {:ok, res} -> res
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  end

  # Sends the transaction and waits for a confirmation or error message
  # from the network via subscriptions.
  # Returns :ok if the transaction is confirmed,
  # {:error, reason} if an error occurs or if the validation times out.
  defp send_tx_and_await_validation(transaction, opts, confirmed_ref, error_ref) do
    case transaction |> RequestHelper.send_transaction() |> request(opts) do
      {:ok, _} ->
        receive do
          %Subscription{ref: ^confirmed_ref} -> :ok
          %Subscription{ref: ^error_ref, message: message} -> {:error, ValidationError.from_map(message)}
        after
          @tx_validation_timeout -> {:error, :timeout}
        end

      er ->
        er
    end
  end
end
