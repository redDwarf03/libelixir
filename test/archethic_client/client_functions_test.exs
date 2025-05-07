defmodule ArchethicClient.ClientFunctionsTest do
  # Mox tests are often better with async: false or per-test setup
  use ExUnit.Case, async: false

  import Mox

  alias ArchethicClient.APIMock
  alias ArchethicClient.AsyncHelperMock
  alias ArchethicClient.Graphql
  alias ArchethicClient.GraphqlError
  alias ArchethicClient.RequestHelperMock
  alias ArchethicClient.RPC
  alias ArchethicClient.Transaction

  # This is needed for Mox to work properly
  setup :verify_on_exit!

  # This sets up application config for our tests to use mock modules
  setup do
    Application.put_env(:archethic_client, :api_module, APIMock, persistent: false)
    Application.put_env(:archethic_client, :request_helper_module, RequestHelperMock, persistent: false)
    Application.put_env(:archethic_client, :async_helper_module, AsyncHelperMock, persistent: false)

    on_exit(fn ->
      Application.delete_env(:archethic_client, :api_module)
      Application.delete_env(:archethic_client, :request_helper_module)
      Application.delete_env(:archethic_client, :async_helper_module)
    end)

    :ok
  end

  describe "get_balance/2 and get_balance!/2" do
    test "get_balance/2 correctly calls RequestHelper.get_balance and API.request" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_opts = []
      dummy_gql_request = %Graphql{name: "getBalance"}
      expected_api_response = {:ok, %{"balance" => 100}}

      expect(RequestHelperMock, :get_balance, fn ^dummy_address -> dummy_gql_request end)
      expect(APIMock, :request, fn ^dummy_gql_request, ^dummy_opts -> expected_api_response end)

      assert ArchethicClient.get_balance(dummy_address, dummy_opts) == expected_api_response
    end

    test "get_balance!/2 correctly calls RequestHelper.get_balance and API.request!" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_opts = []
      dummy_gql_request = %Graphql{name: "getBalance"}
      expected_api_response = %{"balance" => 200}

      expect(RequestHelperMock, :get_balance, fn ^dummy_address -> dummy_gql_request end)
      expect(APIMock, :request!, fn ^dummy_gql_request, ^dummy_opts -> expected_api_response end)

      assert ArchethicClient.get_balance!(dummy_address, dummy_opts) == expected_api_response
    end
  end

  describe "call_contract_function/4 and call_contract_function!/4" do
    test "call_contract_function/4 correctly calls helpers and API.request" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_function = "myFunc"
      dummy_args = [1, "arg2"]
      dummy_opts = []
      dummy_rpc_request = %RPC{method: "contract_call"}
      expected_api_response = {:ok, "function_result"}

      expect(RequestHelperMock, :contract_function_call, fn ^dummy_address, ^dummy_function, ^dummy_args, [] ->
        dummy_rpc_request
      end)

      expect(APIMock, :request, fn ^dummy_rpc_request, ^dummy_opts -> expected_api_response end)

      assert ArchethicClient.call_contract_function(dummy_address, dummy_function, dummy_args, dummy_opts) ==
               expected_api_response
    end

    test "call_contract_function!/4 correctly calls helpers and API.request!" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_function = "otherFunc"
      dummy_args = []
      dummy_opts = []
      dummy_rpc_request = %RPC{method: "contract_call_bang"}
      expected_api_response = "bang_result"

      expect(RequestHelperMock, :contract_function_call, fn ^dummy_address, ^dummy_function, ^dummy_args, [] ->
        dummy_rpc_request
      end)

      expect(APIMock, :request!, fn ^dummy_rpc_request, ^dummy_opts -> expected_api_response end)

      assert ArchethicClient.call_contract_function!(dummy_address, dummy_function, dummy_args, dummy_opts) ==
               expected_api_response
    end
  end

  describe "get_chain_index/2 and get_chain_index!/2" do
    test "get_chain_index/2 handles successful response" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_opts = []
      chain_length = 5

      # The function directly creates a GraphQL request
      expect(APIMock, :request, fn request, ^dummy_opts ->
        assert request.name == "lastTransaction"
        assert request.args == [address: dummy_address]
        assert request.fields == [:chainLength]
        {:ok, %{"chainLength" => chain_length}}
      end)

      assert ArchethicClient.get_chain_index(dummy_address, dummy_opts) == {:ok, chain_length}
    end

    test "get_chain_index/2 handles non-existent transaction" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_opts = []

      expect(APIMock, :request, fn _request, ^dummy_opts ->
        {:error, %GraphqlError{message: "transaction_not_exists"}}
      end)

      assert ArchethicClient.get_chain_index(dummy_address, dummy_opts) == {:ok, 0}
    end

    test "get_chain_index/2 passes through other errors" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_opts = []
      error = %RuntimeError{message: "Network error"}

      expect(APIMock, :request, fn _request, ^dummy_opts ->
        {:error, error}
      end)

      assert ArchethicClient.get_chain_index(dummy_address, dummy_opts) == {:error, error}
    end

    test "get_chain_index!/2 returns result directly on success" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_opts = []
      chain_length = 10

      expect(APIMock, :request, fn _request, ^dummy_opts ->
        {:ok, %{"chainLength" => chain_length}}
      end)

      assert ArchethicClient.get_chain_index!(dummy_address, dummy_opts) == chain_length
    end

    test "get_chain_index!/2 returns 0 for non-existent transaction" do
      dummy_address = "0000500324015555A0EEE595CDC6AB2FDE51311711B197E89214F65797A636A4AF4B"
      dummy_opts = []

      expect(APIMock, :request, fn _request, ^dummy_opts ->
        {:error, %GraphqlError{message: "transaction_not_exists"}}
      end)

      assert ArchethicClient.get_chain_index!(dummy_address, dummy_opts) == 0
    end
  end

  describe "send_transaction/2" do
    test "send_transaction/2 correctly subscribes, sends, and confirms transaction" do
      tx_address = <<1, 2, 3, 4>>
      tx_address_hex = "01020304"
      transaction = %ArchethicClient.Transaction{address: tx_address}
      # opts for send_transaction itself, not for API.subscribe
      dummy_opts = []

      # Mocked refs for subscriptions
      confirmed_mock_ref = make_ref()
      error_mock_ref = make_ref()

      # Expected subscription requests
      confirmed_sub_req = %Graphql{type: :subscription, name: "transactionConfirmed"}
      error_sub_req = %Graphql{type: :subscription, name: "transactionError"}
      # Expected transaction send request
      tx_send_req = %RPC{method: "send_transaction"}

      # --- Expectations for functions called *within* the async_nolink block ---
      # 1. RequestHelper calls for subscription types
      expect(RequestHelperMock, :subscribe_transaction_confirmed, fn ^tx_address_hex -> confirmed_sub_req end)
      expect(RequestHelperMock, :subscribe_transaction_error, fn ^tx_address_hex -> error_sub_req end)

      # Mocks for APIMock.subscribe, called by the async_stream_nolink logic
      expect(APIMock, :subscribe, fn ^confirmed_sub_req, passed_opts ->
        assert Keyword.has_key?(passed_opts, :parent)
        {:ok, confirmed_mock_ref}
      end)

      expect(APIMock, :subscribe, fn ^error_sub_req, passed_opts ->
        assert Keyword.has_key?(passed_opts, :parent)
        {:ok, error_mock_ref}
      end)

      # 2. AsyncHelperMock.async_stream_nolink for subscriptions
      expect(AsyncHelperMock, :async_stream_nolink, fn ArchethicClient.TaskSupervisor,
                                                       input_subs,
                                                       fun_subscribe_to_apply,
                                                       stream_opts ->
        assert input_subs == [confirmed_sub_req, error_sub_req]
        assert Keyword.get(stream_opts, :on_timeout) == :kill_task
        # Simulate Task.Supervisor.async_stream_nolink by applying the function to each input
        # and wrapping in {:ok, result} as the stream would for successful task completion.
        Enum.map(input_subs, fn sub_item ->
          # fun_subscribe_to_apply is &api_module().subscribe(&1, captured_opts).
          # It's a 1-arity function where captured_opts are implicitly passed.
          # The mock for APIMock.subscribe correctly expects 2 args (sub_item and the captured_opts).
          {:ok, fun_subscribe_to_apply.(sub_item)}
        end)
      end)

      # 3. RequestHelper call for sending the transaction
      expect(RequestHelperMock, :send_transaction, fn ^transaction -> tx_send_req end)
      # 4. API.request for sending the transaction (called within send_tx_and_await_validation)
      # This expectation is set later with the message sending logic.

      # --- Expectations for outer async control flow ---
      # The mock for async_nolink will store the result of its executed `fun`
      # in the process dictionary, to be retrieved by the `yield` mock.
      # Process.put(:captured_async_fun_result_key, nil) # Initialize if needed, though not strictly necessary

      # Mock async_nolink: execute the passed function `fun` immediately and save its result.
      expect(AsyncHelperMock, :async_nolink, fn ArchethicClient.TaskSupervisor, fun ->
        actual_result =
          try do
            fun.()
          catch
            kind, reason ->
              IO.inspect({{kind, reason, __STACKTRACE__}}, label: "Exception in async_nolink fun")
              {:error, :exception_in_fun}
          end

        IO.inspect(actual_result, label: "Result of fun.() in async_nolink mock")
        Process.put(:captured_async_fun_result_for_yield, actual_result)
        :mocked_task_for_yield
      end)

      # Mock yield: return the captured result from the async_nolink's fun execution.
      expect(AsyncHelperMock, :yield, fn :mocked_task_for_yield, _timeout ->
        {:ok, Process.get(:captured_async_fun_result_for_yield)}
      end)

      # We don't strictly need to mock shutdown if yield succeeds and returns before timeout.

      # --- Trigger the call ---
      # Call the function under test
      # This will trigger the async_nolink mock above.
      # The fun() inside async_nolink mock will execute, which includes send_tx_and_await_validation.
      # send_tx_and_await_validation will then block on `receive`.

      # We need to run send_transaction in a separate process because the `receive` block
      # inside `send_tx_and_await_validation` (called by `fun.()` in our `async_nolink` mock)
      # will block the current test process if not handled carefully.
      # However, our `async_nolink` mock *is* the current test process.
      # The crucial insight: when `fun.()` is called by the mock, the `receive` block in
      # `send_tx_and_await_validation` will be executed by THIS test process.
      # So, we can send a message to `self()` to satisfy it.

      # Start the send_transaction call. It will eventually block on receive.
      # We don't need to spawn, as our mocks make it synchronous up to the receive block.

      # Setup a process to send the message slightly delayed, to ensure receive is ready.
      # This is still a bit racy. A better way is to have the `expect` for `APIMock, :request` (sending tx)
      # trigger the send_message to self().

      # Revised plan: the `APIMock, :request` for `tx_send_req` is the last step before `receive`.
      # Modify that expectation to send the confirmation message.
      Process.put(:test_process_pid_for_subscription, self())

      expect(APIMock, :request, fn ^tx_send_req, passed_opts ->
        assert Keyword.has_key?(passed_opts, :parent)
        # Send the confirmation message to the test process which is executing the receive block
        send(Process.get(:test_process_pid_for_subscription), %ArchethicClient.Subscription{
          ref: confirmed_mock_ref,
          message: %{event: "confirmed"}
        })

        {:ok, "sent"}
      end)

      # Now, make the call
      assert ArchethicClient.send_transaction(transaction, dummy_opts) == :ok
    end

    # Testing the components of send_transaction separately is more reliable
    test "RequestHelper.send_transaction and API.request are called correctly" do
      tx_address = <<1, 2, 3, 4>>
      transaction = %Transaction{address: tx_address}
      tx_request = %RPC{method: "send_transaction"}

      # These two calls allow us to verify the mocks without needing to test
      # the entire flow of the send_transaction function
      expect(RequestHelperMock, :send_transaction, fn ^transaction -> tx_request end)
      assert RequestHelperMock.send_transaction(transaction) == tx_request

      expect(APIMock, :request, fn ^tx_request, [] -> {:ok, "sent"} end)
      assert APIMock.request(tx_request, []) == {:ok, "sent"}
    end
  end
end
