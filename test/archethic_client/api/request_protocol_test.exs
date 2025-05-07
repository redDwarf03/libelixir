defmodule ArchethicClient.API.RequestProtocolTest do
  use ExUnit.Case, async: true

  alias ArchethicClient.RPC
  alias ArchethicClient.Graphql
  alias ArchethicClient.Request
  alias ArchethicClient.RequestError
  alias ArchethicClient.RPCError
  alias ArchethicClient.GraphqlError

  describe "Request Protocol for ArchethicClient.RPC" do
    @rpc_request %RPC{method: "test_method", params: %{p1: "v1"}}
    @rpc_request_id "rpc_0"

    test "type/1 returns :rpc" do
      assert Request.type(@rpc_request) == :rpc
    end

    test "subscription?/1 returns false" do
      assert Request.subscription?(@rpc_request) == false
    end

    test "request_id/2 generates correct ID" do
      assert Request.request_id(@rpc_request, 0) == "rpc_0"
      assert Request.request_id(@rpc_request, 10) == "rpc_10"
    end

    test "format_body/2 creates correct JSON-RPC map" do
      expected_body = %{
        jsonrpc: "2.0",
        id: @rpc_request_id,
        method: "test_method",
        params: %{p1: "v1"}
      }
      assert Request.format_body(@rpc_request, @rpc_request_id) == expected_body
    end

    test "format_message/3 returns message as is" do
      message = %{"some" => "data"}
      assert Request.format_message(@rpc_request, @rpc_request_id, message) == message
    end
  end

  describe "Request.format_response/3 for ArchethicClient.RPC" do
    @rpc_request %RPC{method: "test_method", params: %{p1: "v1"}}
    @rpc_request_id "rpc_0"

    test "handles successful response with result" do
      response_body = %{"result" => "success_data"}
      req_response = %Req.Response{status: 200, body: response_body}
      assert Request.format_response(@rpc_request, @rpc_request_id, req_response) == {:ok, "success_data"}
    end

    test "handles response with RPC error" do
      error_data = %{"code" => -32000, "message" => "Server error", "data" => "details"}
      response_body = %{"error" => error_data}
      req_response = %Req.Response{status: 200, body: response_body}
      expected_error = %RPCError{
        message: "Server error",
        code: -32000,
        data: "details"
      }
      assert Request.format_response(@rpc_request, @rpc_request_id, req_response) == {:error, expected_error}
    end

    test "handles batch response by finding correct ID (success)" do
      batch_response_body = [
        %{"id" => "rpc_other", "result" => "other_data"},
        %{"id" => @rpc_request_id, "result" => "my_data"}
      ]
      req_response = %Req.Response{status: 200, body: batch_response_body}
      assert Request.format_response(@rpc_request, @rpc_request_id, req_response) == {:ok, "my_data"}
    end

    test "handles batch response by finding correct ID (error)" do
      error_data = %{"code" => -32001, "message" => "My Error"}
      batch_response_body = [
        %{"id" => "rpc_other", "result" => "other_data"},
        %{"id" => @rpc_request_id, "error" => error_data}
      ]
      req_response = %Req.Response{status: 200, body: batch_response_body}
      expected_error = %RPCError{message: "My Error", code: -32001, data: nil}
      assert Request.format_response(@rpc_request, @rpc_request_id, req_response) == {:error, expected_error}
    end

    test "handles HTTP error status" do
      req_response = %Req.Response{status: 500, body: "Server Down"}
      expected_error = %RequestError{http_status: 500, body: "Server Down"}
      assert Request.format_response(@rpc_request, @rpc_request_id, req_response) == {:error, expected_error}
    end
  end

  describe "Request Protocol for ArchethicClient.Graphql" do
    @gql_query %Graphql{name: "getBalance", args: [address: "0x123"], fields: [:balance, :uco_balance]}
    @gql_subscription %Graphql{name: "chainUpdate", type: :subscription, fields: [:new_block]}
    @gql_request_id "graphql_0"

    test "type/1 returns :graphql_query or :graphql_subscription" do
      assert Request.type(@gql_query) == :graphql_query
      assert Request.type(@gql_subscription) == :graphql_subscription
    end

    test "subscription?/1 identifies subscriptions" do
      assert Request.subscription?(@gql_query) == false
      assert Request.subscription?(@gql_subscription) == true
    end

    test "request_id/2 generates correct ID" do
      assert Request.request_id(@gql_query, 0) == "graphql_0"
      assert Request.request_id(@gql_subscription, 5) == "graphql_5"
    end

    test "format_body/2 creates correct string (uses String.Chars)" do
      expected_query_string = "getBalance(address: \"0x123\"){ balance, uco_balance}"
      assert Request.format_body(@gql_query, @gql_request_id) == "#{@gql_request_id}: #{expected_query_string}"
    end

    test "format_message/3 extracts data for request_id" do
      message = %{"data" => %{@gql_request_id => "subscription_update"}}
      assert Request.format_message(@gql_subscription, @gql_request_id, message) == "subscription_update"
    end
  end

  describe "Request.format_response/3 for ArchethicClient.Graphql" do
    @gql_query %Graphql{name: "getBalance", args: [address: "0x123"], fields: [:balance, :uco_balance]}
    @gql_subscription %Graphql{name: "chainUpdate", type: :subscription, fields: [:new_block]}
    @gql_request_id "graphql_0"

    test "handles successful query response" do
      response_body = %{"data" => %{@gql_request_id => %{"balance" => 100}}}
      req_response = %Req.Response{status: 200, body: response_body}
      assert Request.format_response(@gql_query, @gql_request_id, req_response) == {:ok, %{"balance" => 100}}
    end

    test "handles query response with GraphQL error" do
      error_details = [%{"path" => [@gql_request_id, "balance"], "locations" => [%{"line" => 1}], "message" => "Field error"}]
      response_body = %{"data" => %{@gql_request_id => nil}, "errors" => error_details}
      req_response = %Req.Response{status: 200, body: response_body}
      expected_error = %GraphqlError{message: "Field error", location: %{"line" => 1}}
      assert Request.format_response(@gql_query, @gql_request_id, req_response) == {:error, expected_error}
    end

    test "handles successful subscription handshake response" do
      response_body = %{"payload" => %{"message" => "ack"}}
      req_response = %Req.Response{status: 200, body: response_body} # Subscription handshake
      assert Request.format_response(@gql_subscription, "graphql_sub_0", req_response) == {:ok, response_body}
    end

    test "handles HTTP error status for GraphQL" do
      req_response = %Req.Response{status: 401, body: "Unauthorized"}
      expected_error = %RequestError{http_status: 401, body: "Unauthorized"}
      assert Request.format_response(@gql_query, @gql_request_id, req_response) == {:error, expected_error}
    end
  end

  describe "String.Chars Protocol for ArchethicClient.Graphql" do
    test "to_string/1 for simple query" do
      gql = %Graphql{name: "simpleQuery", fields: [:fieldA, :fieldB]}
      assert to_string(gql) == "simpleQuery{ fieldA, fieldB}"
    end

    test "to_string/1 for query with args" do
      gql = %Graphql{name: "queryWithArgs", args: [id: 123, name: "test"], fields: [:data]}
      assert to_string(gql) == "queryWithArgs(id: 123, name: \"test\"){ data}"
    end

    test "to_string/1 for query with nil arg" do
      gql = %Graphql{name: "queryWithNilArg", args: [filter: nil], fields: [:data]}
      assert to_string(gql) == "queryWithNilArg(filter: null){ data}"
    end

    test "to_string/1 for query with nested fields" do
      gql = %Graphql{name: "nestedQuery", fields: [:simple, {:complex, [:c1, :c2]}, :another]}
      assert to_string(gql) == "nestedQuery{ simple, complex { c1, c2}, another}"
    end

    test "to_string/1 for query with args and nested fields" do
      gql = %Graphql{name: "fullQuery", args: [token: "abc"], fields: [:id, {:user, [:name, :email]}]}
      assert to_string(gql) == "fullQuery(token: \"abc\"){ id, user { name, email}}"
    end

    test "to_string/1 for subscription (same as query stringification)" do
      gql = %Graphql{type: :subscription, name: "chainUpdate", fields: [{:block, [:hash, :number]}]}
      assert to_string(gql) == "chainUpdate{ block { hash, number}}"
    end
  end
end
