defprotocol ArchethicClient.Request do
  @moduledoc """
  Defines a protocol for requests made to the Archethic network.

  This protocol standardizes how different types of requests (e.g., RPC, GraphQL)
  are processed. Implementations of this protocol must define functions to:
  - Determine the request type (e.g., `:rpc`, `:graphql_query`).
  - Check if the request is a subscription.
  - Format the request into a suitable body for HTTP/WebSocket transmission.
  - Format the response received from the network.
  - Generate a unique ID for the request, especially in batch scenarios.
  - Format messages received via WebSocket subscriptions.
  """

  @type t(_element) :: t()

  @doc """
  Returns the specific type of the request (e.g., `:rpc`, `:graphql_query`, `:graphql_subscription`).

  This helps in routing the request to the appropriate handler or endpoint.
  """
  @spec type(request :: t()) :: type :: atom()
  def type(request)

  @doc """
  Determines if the request is a subscription type (e.g., GraphQL subscription).

  Returns `true` if it is a subscription, `false` otherwise.
  This influences how the request is handled, particularly regarding WebSocket connections.
  """
  @spec subscription?(request :: t()) :: boolean()
  def subscription?(request)

  @doc """
  Formats the request data into the body to be sent via an HTTP or WebSocket request.

  The `request_id` is often incorporated into the body for batch requests or to correlate responses.
  """
  @spec format_body(request :: t(), request_id :: term()) :: term()
  def format_body(request, request_id)

  @doc """
  Processes and formats the `Req.Response.t()` struct received from the network.

  This function should parse the raw HTTP response and transform it into a more
  usable Elixir term, typically `{:ok, result}` or `{:error, reason}`.
  The `request_id` can be used to extract specific parts of a batched response.
  """
  @spec format_response(request :: t(), request_id :: term(), response :: Req.Response.t()) ::
          {:ok, term()} | {:error, Exception.t()}
  def format_response(request, request_id, response)

  @doc """
  Generates a unique identifier for the request, typically using an index.

  This is crucial for batching requests and correlating responses, ensuring each
  sub-request in a batch can be uniquely identified.
  """
  @spec request_id(request :: t(), index :: non_neg_integer()) :: term()
  def request_id(request, index)

  @doc """
  Formats an incoming message received through a WebSocket subscription.

  This function processes the raw message from the WebSocket and transforms it
  into a more usable Elixir term, often correlating it with the `request_id`.
  """
  @spec format_message(request :: t(), request_id :: term(), message :: term()) :: term()
  def format_message(request, request_id, message)
end
