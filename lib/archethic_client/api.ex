defmodule ArchethicClient.API do
  @moduledoc """
  Provides functions for sending requests to the Archethic network.

  This module handles single requests, batch requests, and subscriptions
  to network events. It also includes support for mock requests for testing
  purposes.
  """

  alias ArchethicClient.API.SubscriptionSupervisor
  alias ArchethicClient.APIError
  alias ArchethicClient.APITest
  alias ArchethicClient.Request
  alias ArchethicClient.Subscription
  alias ArchethicClient.TaskSupervisor

  if Mix.env() == :test do
    @behaviour ArchethicClient.Test.Behaviors.API
  end

  @type request_opts :: [base_url: String.t(), parent: pid()]

  @doc """
  Send a request to Archethic network
  """
  @spec request(request :: Request.t(), opts :: request_opts()) ::
          {:ok, term()} | {:error, reason :: Exception.t()}
  def request(request, opts \\ []) do
    cond do
      Request.subscription?(request) ->
        {:error, %APIError{request: request, message: "Cannot request on subscription"}}

      Application.get_env(:archethic_client, :enable_mock?, false) ->
        do_mock_request(request)

      true ->
        do_request(request, opts)
    end
  end

  # Internal helper to perform a standard HTTP request to the Archethic network.
  # It constructs the request using Req and formats the response.
  defp do_request(request, opts) do
    base_url =
      opts
      |> Keyword.validate!([:base_url, :parent])
      |> Keyword.get_lazy(:base_url, fn -> Application.fetch_env!(:archethic_client, :base_url) end)

    client_opts = Application.get_env(:archethic_client, :req_request_opts, [])

    request_id = Request.request_id(request, 0)
    body = Request.format_body(request, request_id)

    req = [base_url: base_url] |> Req.new() |> prepare_req(Request.type(request), body) |> Req.merge(client_opts)

    case Req.request(req) do
      {:ok, response} -> Request.format_response(request, request_id, response)
      {:error, reason} -> {:error, reason}
    end
  end

  # Internal helper to perform a mock request for testing.
  # It uses Req.Test to simulate network responses.
  defp do_mock_request(request) do
    req =
      [base_url: "http://localhost:4000"]
      |> Req.new()
      |> Req.Request.put_private(:archethic_client, request)
      |> Req.merge(plug: {Req.Test, APITest}, into: &APITest.parse_resp/2)

    me = self()
    owner_pid = me |> Process.info(:dictionary) |> elem(1) |> Keyword.get(:"$ancestors", []) |> List.last(me)

    Req.Test.allow(APITest, owner_pid, me)

    case Req.request(req) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as request/2 but raise on error
  """
  @spec request!(request :: Request.t(), opts :: request_opts()) :: term()
  def request!(request, opts \\ []) do
    case request(request, opts) do
      {:ok, res} -> res
      {:error, reason} when is_exception(reason) -> raise reason
    end
  end

  @doc """
  Subscribe to event on Archethic network
  """
  @spec subscribe(request :: Request.t(), opts :: request_opts()) ::
          {:ok, subscription_ref :: reference()} | {:error, Exception.t()}
  def subscribe(request, opts \\ []) do
    if Request.subscription?(request) do
      opts = Keyword.validate!(opts, [:base_url, parent: self()])
      parent = Keyword.fetch!(opts, :parent)
      base_url = Keyword.get_lazy(opts, :base_url, fn -> Application.fetch_env!(:archethic_client, :base_url) end)

      client_opts = Application.get_env(:archethic_client, :req_subscription_opts, [])

      request_id = Request.request_id(request, 0)
      body = Request.format_body(request, request_id)

      {ws, req} = [base_url: base_url] |> Req.new() |> prepare_sub(Request.type(request), body, parent)
      req = Req.merge(req, client_opts)

      case DynamicSupervisor.start_child(
             SubscriptionSupervisor,
             {Subscription, ws: ws, req: req, request: request, request_id: request_id, send_to: parent}
           ) do
        {:ok, _pid, ref} -> {:ok, ref}
        er -> er
      end
    else
      {:error, %APIError{request: request, message: "Not a subscription"}}
    end
  end

  @doc """
  Batch multiple Request into a single request per Request type
  It keeps the same order as the request list provided
  """
  @spec batch_requests(requests :: list(Request.t()), opts :: request_opts()) ::
          list({:ok, term()} | {:error, Exception.t()})
  def batch_requests(requests, opts \\ []) do
    Keyword.validate!(opts, [:base_url])

    base_url =
      Keyword.get(opts, :base_url, Application.fetch_env!(:archethic_client, :base_url))

    indexed_requests = Enum.with_index(requests)

    group_by_subscription =
      Enum.group_by(indexed_requests, fn {request, _} -> Request.subscription?(request) end)

    indexed_subscriptions_res =
      group_by_subscription
      |> Map.get(true, [])
      |> Enum.map(fn {request, index} ->
        error = {:error, %APIError{request: request, message: "Cannot request on subscription"}}
        {index, error}
      end)

    requests_by_type =
      group_by_subscription
      |> Map.get(false, [])
      |> Enum.group_by(fn {request, _} -> Request.type(request) end)

    TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(
      requests_by_type,
      fn {request_type, indexed_requests} ->
        do_batch_request(base_url, request_type, indexed_requests)
      end,
      on_timeout: :kill_task,
      zip_input_on_exit: true
    )
    |> Stream.flat_map(fn
      {:ok, res} ->
        res

      {:exit, {{_, missed_indexed_requests}, :timeout}} ->
        Enum.map(missed_indexed_requests, fn {_, index} ->
          {index, {:error, %RuntimeError{message: "Timeout"}}}
        end)

      {:exit, {{_, missed_indexed_requests}, reason}} ->
        Enum.map(missed_indexed_requests, fn {_, index} -> {index, {:error, reason}} end)
    end)
    |> Stream.concat(indexed_subscriptions_res)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  @doc """
  Same as batch_requests/2 but raise on error
  """
  @spec batch_requests!(requests :: list(Request.t()), opts :: request_opts()) :: list(term())
  def batch_requests!(requests, opts \\ []) do
    results = batch_requests(requests, opts)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> results
      {:error, reason} -> raise reason
    end
  end

  # Internal helper to perform a batch request for a specific request type.
  # It groups requests by type and sends them as a single HTTP request.
  defp do_batch_request(base_url, request_type, indexed_requests) do
    indexed_requests_with_id =
      Enum.map(indexed_requests, fn {request, index} ->
        {index, request, Request.request_id(request, index)}
      end)

    bodies =
      Enum.map(indexed_requests_with_id, fn {_, request, request_id} ->
        Request.format_body(request, request_id)
      end)

    req = [base_url: base_url] |> Req.new() |> prepare_req(request_type, bodies)

    case Req.request(req) do
      {:ok, response} ->
        Enum.map(indexed_requests_with_id, fn {index, request, request_id} ->
          {index, Request.format_response(request, request_id, response)}
        end)

      {:error, reason} ->
        Enum.map(indexed_requests, fn {_, index} -> {index, {:error, reason}} end)
    end
  end

  # Prepares a Req request for RPC calls.
  defp prepare_req(req, :rpc, body), do: Req.merge(req, method: :post, url: "/api/rpc", json: body)

  # Prepares a Req request for GraphQL queries.
  defp prepare_req(req, :graphql_query, body) do
    req
    |> AbsintheClient.attach(graphql: "query { #{format_graphql(body)} }")
    |> Req.merge(method: :post, url: "/api")
  end

  # Prepares a Req request and WebSocket connection for GraphQL subscriptions.
  defp prepare_sub(req, :graphql_subscription, body, parent) do
    req = AbsintheClient.attach(req, graphql: "subscription { #{format_graphql(body)} }")

    case AbsintheClient.WebSocket.connect(req, parent: parent) do
      {:ok, ws} -> {ws, Req.merge(req, web_socket: ws, method: :post, url: "/api")}
      er -> er
    end
  end

  # Formats a list of GraphQL queries into a single string.
  defp format_graphql(queries) when is_list(queries), do: Enum.join(queries, ", ")
  # Returns the GraphQL query string as is if it's not a list.
  defp format_graphql(query), do: query
end
