defmodule ArchethicClient.Subscription do
  @moduledoc """
  A `GenServer` responsible for managing a single WebSocket subscription to the Archethic network.

  It handles the lifecycle of a subscription, including initiation via `AbsintheClient`,
  receiving messages, formatting them using the `ArchethicClient.Request` protocol,
  and forwarding them to the process that initiated the subscription.
  It also handles unsubscription and monitors the underlying WebSocket connection.
  Each subscription `GenServer` is registered in the `ArchethicClient.API.SubscriptionRegistry`.
  """

  use GenServer, restart: :transient

  alias ArchethicClient.API.SubscriptionRegistry
  alias ArchethicClient.Request

  @enforce_keys [:ref, :message]
  defstruct [:ref, :message]

  @doc """
  Starts and links a new subscription `GenServer`.

  A unique reference (`ref`) is generated for this subscription, and the `GenServer`
  is registered in the `SubscriptionRegistry` using this reference.
  Returns `{:ok, pid, ref}` on success, where `ref` is the unique subscription reference.
  """
  def start_link(args) do
    ref = make_ref()

    case GenServer.start_link(__MODULE__, Keyword.put(args, :ref, ref), name: via_tuple(ref)) do
      {:ok, pid} -> {:ok, pid, ref}
      er -> er
    end
  end

  # Creates a `via` tuple for registering and looking up the GenServer in the Registry.
  # This allows addressing the GenServer by its unique `ref` instead of its `pid`.
  defp via_tuple(ref), do: {:via, Registry, {SubscriptionRegistry, ref}}

  @doc """
  Requests the unsubscription from the Archethic network for the given subscription.

  This sends an asynchronous `:unsubscribe` cast to the `Subscription` GenServer
  identified by its `ref` (which is part of the `ArchethicClient.Subscription` struct
  passed to the client process when a message is received).
  """
  def unsubscribe(%__MODULE__{ref: ref}), do: ref |> via_tuple() |> GenServer.cast(:unsubscribe)

  @impl true
  @doc """
  Initializes the subscription `GenServer`.

  It validates arguments, sends the initial subscription request via `Req`,
  formats the response using the `Request` protocol to get the Absinthe subscription reference,
  and monitors the WebSocket connection process (`ws`).

  The state includes references to the WebSocket, the client request, request ID,
  the process to send messages to (`send_to`), and the Absinthe subscription reference (`sub_ref`).
  """
  def init(args) do
    [ref: ref, req: req, request: request, request_id: request_id, send_to: send_to, ws: ws] =
      args |> Keyword.validate!([:ws, :req, :request, :request_id, :send_to, :ref]) |> Enum.sort()

    with {:ok, response} <- Req.request(req),
         {:ok, %AbsintheClient.Subscription{ref: sub_ref}} <- Request.format_response(request, request_id, response) do
      ws_ref = ws |> GenServer.whereis() |> Process.monitor()

      state = %{
        ws: ws,
        ref: ref,
        ws_ref: ws_ref,
        request: request,
        request_id: request_id,
        send_to: send_to,
        sub_ref: sub_ref
      }

      {:ok, state}
    else
      er -> {:stop, er}
    end
  end

  @impl true
  @doc """
  Handles the `:unsubscribe` cast message.

  It instructs `AbsintheClient.WebSocket` to clear subscriptions on the WebSocket
  and then stops the `GenServer` gracefully.
  """
  def handle_cast(:unsubscribe, %{ws: ws} = state) do
    AbsintheClient.WebSocket.clear_subscriptions(ws)
    {:stop, :shutdown, state}
  end

  @impl true
  @doc """
  Handles incoming messages and monitored process `:DOWN` events.

  - For `AbsintheClient.WebSocket.Message` instances:
    If the message reference matches the active Absinthe subscription reference (`sub_ref`),
    it formats the payload using `Request.format_message/3` and sends the resulting
    `ArchethicClient.Subscription` struct (containing the unique `ref` and the formatted `message`)
    to the `send_to` process.

  - For `{:DOWN, ...}` messages:
    Indicates that the monitored WebSocket connection process has terminated.
    This triggers a graceful shutdown of the subscription `GenServer`.
  """
  def handle_info(
        %AbsintheClient.WebSocket.Message{ref: sub_ref, payload: payload},
        %{sub_ref: sub_ref, request: request, request_id: request_id, send_to: send_to, ref: ref} = state
      ) do
    res = Request.format_message(request, request_id, payload)
    send(send_to, %__MODULE__{ref: ref, message: res})

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _}, %{ws_ref: ref} = state), do: {:stop, :shutdown, state}
end
