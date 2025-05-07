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

  # Get the real async helper module from config or use default
  defp async_helper_module,
    do: Application.get_env(:archethic_client, :async_helper_module, ArchethicClient.RealAsyncHelper)

  @tx_validation_timeout 60_000

  # Get the API module from config or use default
  defp api_module, do: Application.get_env(:archethic_client, :api_module, API)

  # Get the RequestHelper module from config or use default
  defp request_helper_module, do: Application.get_env(:archethic_client, :request_helper_module, RequestHelper)

  @doc """
  Send a request to Archethic network
  """
  @spec request(request :: Request.t(), opts :: API.request_opts()) :: {:ok, term()} | {:error, Exception.t()}
  def request(request, opts \\ []), do: api_module().request(request, opts)

  @doc """
  Same as request/2 but raise on error
  """
  @spec request!(request :: Request.t(), opts :: API.request_opts()) :: term()
  def request!(request, opts \\ []), do: api_module().request!(request, opts)

  @doc """
  Batch multiple Request into a single request per Request type
  It keeps the same order as the request list provided
  """
  @spec batch_requests(requests :: list(Request.t()), opts :: API.request_opts()) ::
          list({:ok, term()} | {:error, Exception.t()})
  def batch_requests(requests, opts \\ []), do: api_module().batch_requests(requests, opts)

  @doc """
  Same as batch_requests/2 but raise on error
  """
  @spec batch_requests!(requests :: list(Request.t()), opts :: API.request_opts()) :: list(term())
  def batch_requests!(requests, opts \\ []), do: api_module().batch_requests!(requests, opts)

  @doc """
  Returns the balance of a genesis address
  Shortcut of `address |> RequestHelper.get_balance() |> ArchethicClient.request()`
  """
  @spec get_balance(genesis_address :: Crypto.hex_address(), opts :: API.request_opts()) ::
          {:ok, map()} | {:error, Exception.t()}
  def get_balance(genesis_address, opts \\ []) do
    genesis_address
    |> request_helper_module().get_balance()
    |> request(opts)
  end

  @doc """
  Same as `get_balance/2` but raise on error
  """
  @spec get_balance!(genesis_address :: Crypto.hex_address(), opts :: API.request_opts()) :: map()
  def get_balance!(genesis_address, opts \\ []) do
    genesis_address
    |> request_helper_module().get_balance()
    |> request!(opts)
  end

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
  def call_contract_function(contract_address, function, args \\ [], opts \\ []) do
    # Extract any contract function call options (like resolve_last?) and API request options
    {contract_function_call_opts, request_opts} = Keyword.split(opts, [:resolve_last?])

    contract_address
    |> request_helper_module().contract_function_call(function, args, contract_function_call_opts)
    |> request(request_opts)
  end

  @doc """
  Same as `call_contract_function/4` but raise on error
  """
  @spec call_contract_function!(
          contract_address :: Crypto.hex_address(),
          function :: String.t(),
          args :: list(),
          opts :: API.request_opts()
        ) :: term()
  def call_contract_function!(contract_address, function, args \\ [], opts \\ []) do
    # Extract any contract function call options (like resolve_last?) and API request options
    {contract_function_call_opts, request_opts} = Keyword.split(opts, [:resolve_last?])

    contract_address
    |> request_helper_module().contract_function_call(function, args, contract_function_call_opts)
    |> request!(request_opts)
  end

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
    confirmed_sub = request_helper_module().subscribe_transaction_confirmed(address_hex)
    error_sub = request_helper_module().subscribe_transaction_error(address_hex)

    # Runs in a task to close web socket after transaction validation
    task =
      async_helper_module().async_nolink(TaskSupervisor, fn ->
        opts = Keyword.put(opts, :parent, self())

        subscriptions =
          TaskSupervisor
          |> async_helper_module().async_stream_nolink([confirmed_sub, error_sub], &api_module().subscribe(&1, opts),
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

    case async_helper_module().yield(task, @tx_validation_timeout * 2) ||
           async_helper_module().shutdown(task, :brutal_kill) do
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
    case transaction |> request_helper_module().send_transaction() |> request(opts) do
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
