defmodule ArchethicClient.APIError do
  @moduledoc """
  Represents a generic error originating from the `ArchethicClient.API` module.

  This exception is typically raised for issues encountered during the setup or
  execution of an API request before it reaches the network, or for issues that
  don't fit into more specific error categories.
  """

  defexception [:request, :message]
end

defmodule ArchethicClient.GraphqlError do
  @moduledoc """
  Represents an error returned by the Archethic network in response to a GraphQL request.

  It includes information about the error message and optionally the location
  within the GraphQL query where the error occurred.
  """

  defexception [:location, :message]
end

defmodule ArchethicClient.RPCError do
  @moduledoc """
  Represents an error returned by the Archethic network in response to an RPC request.

  Contains the error message, a specific error code, and potentially additional data
  related to the error.
  """

  defexception [:message, :code, :data]

  @doc """
  Formats the error message for an `RPCError`.

  It combines the main error message with any nested messages found in the `data` field.
  """
  def message(%__MODULE__{message: message, data: data}) do
    messages = data |> stringify_data()
    Enum.join([message | messages], ": ")
  end

  defp stringify_data(data) do
    do_stringify_data(data, []) |> Enum.reverse()
  end

  defp do_stringify_data(data_item, acc) when is_binary(data_item) do
    [data_item | acc]
  end
  defp do_stringify_data(%{"message" => msg, "data" => nested_data}, acc) when is_binary(msg) do
    do_stringify_data(nested_data, [msg | acc])
  end
  defp do_stringify_data(_data_item, acc) do
    acc
  end
end

defmodule ArchethicClient.ValidationError do
  @moduledoc """
  Represents an error returned by the Archethic network during transaction validation.

  This typically occurs after a transaction has been sent and the network
  detects an issue with its content, signatures, or context.
  """
  defexception [:address, :context, :message, :code, :data]

  @doc """
  Formats the error message for a `ValidationError`.

  Combines the context, main message, and any nested messages from the `data` field.
  """
  def message(%__MODULE__{context: context, message: message, data: data}) do
    messages = stringify_data(data)
    Enum.join([context, message | messages], ": ")
  end

  defp stringify_data(data) do
    do_stringify_data(data, []) |> Enum.reverse()
  end

  defp do_stringify_data(data_item, acc) when is_binary(data_item) do
    [data_item | acc]
  end
  defp do_stringify_data(%{"message" => msg, "data" => nested_data}, acc) when is_binary(msg) do
    do_stringify_data(nested_data, [msg | acc])
  end
  defp do_stringify_data(_data_item, acc) do
    acc
  end

  @doc """
  Transform a map to a validation error exception
  """
  @spec from_map(map :: map()) :: Exception.t()
  def from_map(%{
        "address" => address,
        "context" => context,
        "error" => %{"code" => code, "message" => message, "data" => data}
      }),
      do: %__MODULE__{address: address, context: context, code: code, message: message, data: data}
end

defmodule ArchethicClient.RequestError do
  @moduledoc """
  Represents an error related to an HTTP request, typically an unexpected HTTP status code.

  This exception is raised when an HTTP request made by the client
  receives a response status that indicates an error (e.g., 4xx or 5xx).
  It includes the HTTP status and the response body.
  """

  # Inspired by Plug.Conn.Status
  # https://github.com/elixir-plug/plug/blob/main/lib/plug/conn/status.ex
  @statuses %{
    100 => "Continue",
    101 => "Switching Protocols",
    102 => "Processing",
    103 => "Early Hints",
    200 => "OK",
    201 => "Created",
    202 => "Accepted",
    203 => "Non-Authoritative Information",
    204 => "No Content",
    205 => "Reset Content",
    206 => "Partial Content",
    207 => "Multi-Status",
    208 => "Already Reported",
    226 => "IM Used",
    300 => "Multiple Choices",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    305 => "Use Proxy",
    306 => "Switch Proxy",
    307 => "Temporary Redirect",
    308 => "Permanent Redirect",
    400 => "Bad Request",
    401 => "Unauthorized",
    402 => "Payment Required",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    406 => "Not Acceptable",
    407 => "Proxy Authentication Required",
    408 => "Request Timeout",
    409 => "Conflict",
    410 => "Gone",
    411 => "Length Required",
    412 => "Precondition Failed",
    413 => "Request Entity Too Large",
    414 => "Request-URI Too Long",
    415 => "Unsupported Media Type",
    416 => "Requested Range Not Satisfiable",
    417 => "Expectation Failed",
    418 => "I'm a teapot",
    421 => "Misdirected Request",
    422 => "Unprocessable Entity",
    423 => "Locked",
    424 => "Failed Dependency",
    425 => "Too Early",
    426 => "Upgrade Required",
    428 => "Precondition Required",
    429 => "Too Many Requests",
    431 => "Request Header Fields Too Large",
    451 => "Unavailable For Legal Reasons",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout",
    505 => "HTTP Version Not Supported",
    506 => "Variant Also Negotiates",
    507 => "Insufficient Storage",
    508 => "Loop Detected",
    510 => "Not Extended",
    511 => "Network Authentication Required"
  }

  defexception [:http_status, :body]

  @doc """
  Formats the error message for a `RequestError`.

  If the body is empty, it uses a standard message for the HTTP status code.
  Otherwise, it attempts to extract an error message from the body.
  """
  @spec message(exception :: Exception.t()) :: message :: String.t()
  def message(%__MODULE__{http_status: status, body: ""}), do: Map.get(@statuses, status, "Unknown http status error")

  def message(%__MODULE__{body: body}) when is_binary(body), do: body
  def message(%__MODULE__{body: %{"error" => error}}) when is_binary(error), do: error

  def message(%__MODULE__{body: %{"error" => %{"message" => message}}}) when is_binary(message), do: message
end
