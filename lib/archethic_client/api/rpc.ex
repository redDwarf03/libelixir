defmodule ArchethicClient.RPC do
  @moduledoc """
  Defines the structure for JSON-RPC requests and implements the `ArchethicClient.Request`
  protocol for their processing.

  This module allows for the construction of RPC requests, their formatting according
  to the JSON-RPC 2.0 specification, and the parsing of responses from the Archethic network.
  """

  alias ArchethicClient.Request

  @enforce_keys :method
  defstruct [:method, params: []]

  @type t :: %__MODULE__{
          method: String.t(),
          params: map()
        }

  defimpl Request, for: ArchethicClient.RPC do
    alias ArchethicClient.RequestError
    alias ArchethicClient.RPC
    alias ArchethicClient.RPCError

    @doc """
    Returns the type of the request, which is always `:rpc` for this module.
    """
    @spec type(request :: RPC.t()) :: :rpc
    def type(_), do: :rpc

    @doc """
    Indicates that RPC requests are not subscriptions.
    Always returns `false`.
    """
    @spec subscription?(request :: RPC.t()) :: false
    def subscription?(_), do: false

    @doc """
    Generates a unique request ID for the RPC request.
    The ID is prefixed with "rpc_" followed by an index. This is part of the JSON-RPC 2.0 spec.
    """
    @spec request_id(request :: RPC.t(), index :: non_neg_integer()) :: String.t()
    def request_id(_, index), do: "rpc_#{index}"

    @doc """
    Formats the body for the JSON-RPC request.
    Constructs a map conforming to the JSON-RPC 2.0 specification, including
    `jsonrpc`, `id`, `method`, and `params`.
    """
    @spec format_body(request :: RPC.t(), request_id :: String.t()) :: map()
    def format_body(%RPC{method: method, params: params}, request_id),
      do: %{jsonrpc: "2.0", id: request_id, method: method, params: params}

    @doc """
    Formats an incoming message related to an RPC request.
    For standard RPC, messages are typically direct responses, so this function
    currently returns the message as is. It might be used differently if RPC
    was extended over WebSockets with non-standard message flows.
    """
    @spec format_message(request :: RPC.t(), request_id :: String.t(), message :: term()) :: term()
    def format_message(_, _, message), do: message

    @doc """
    Formats the HTTP response received for an RPC request.

    - If the response body contains a `"result"` key, it's considered a successful RPC call.
    - If it contains an `"error"` key, it's transformed into an `ArchethicClient.RPCError`.
    - If the response body is a list (batch response), it finds the response matching the `request_id`
      and processes it recursively.
    - For other HTTP errors, it returns an `ArchethicClient.RequestError`.
    """
    @spec format_response(
            request :: RPC.t(),
            request_id :: String.t(),
            response :: Req.Response.t()
          ) :: {:ok, term()} | {:error, Exception.t()}
    def format_response(_, _, %Req.Response{status: 200, body: %{"result" => result}}), do: {:ok, result}

    def format_response(_, _, %Req.Response{status: 200, body: %{"error" => error}}) do
      rpc_error = %RPCError{
        message: Map.get(error, "message"),
        code: Map.get(error, "code"),
        data: Map.get(error, "data")
      }

      {:error, rpc_error}
    end

    def format_response(request, request_id, %Req.Response{status: 200, body: results} = response)
        when is_list(results) do
      request_response = Enum.find(results, nil, &match?(^request_id, &1["id"]))
      format_response(request, request_id, %Req.Response{response | body: request_response})
    end

    def format_response(_, _, %Req.Response{status: status, body: body}) do
      {:error, %RequestError{http_status: status, body: body}}
    end
  end
end
