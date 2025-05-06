defmodule ArchethicClient.Graphql do
  @moduledoc """
  Defines the structure for representing GraphQL requests and implements
  necessary protocols for their processing.

  This module allows for the construction of GraphQL queries and subscriptions,
  their conversion to string format for network transmission, and the parsing
  of responses from the Archethic network.
  """

  alias ArchethicClient.Request

  @enforce_keys :name
  defstruct [:name, type: :query, args: [], fields: []]

  @type t :: %__MODULE__{
          type: :query | :subscription,
          name: String.t(),
          args: Keyword.t(),
          fields: list(field :: atom() | {type :: atom(), fields :: list()})
        }

  defimpl String.Chars, for: __MODULE__ do
    alias ArchethicClient.Graphql

    @doc """
    Converts a `ArchethicClient.Graphql` struct into its string representation.

    This is used to build the GraphQL query or subscription string that will be
    sent to the Archethic network.
    """
    @spec to_string(struct :: Graphql.t()) :: String.t()
    def to_string(%Graphql{name: name, args: args, fields: fields}) do
      string_fields = stringify_fields(fields)

      case Enum.map_join(args, ", ", &stringify_arg/1) do
        "" -> "#{name}{#{string_fields}}"
        string_args -> "#{name}(#{string_args}){#{string_fields}}"
      end
    end

    # Stringifies a single GraphQL argument key-value pair.
    # Handles binary values (strings), nil, and other types.
    defp stringify_arg({key, value}) when is_binary(value), do: "#{key}: \"#{value}\""
    defp stringify_arg({key, value}) when is_nil(value), do: "#{key}: null"
    defp stringify_arg({key, value}), do: "#{key}: #{value}"

    # Recursively stringifies a list of GraphQL fields.
    defp stringify_fields(fields, acc \\ "")
    # Base case: returns the accumulated string when no fields are left.
    defp stringify_fields([], acc), do: acc

    # Handles a simple atom field when the accumulator is empty.
    defp stringify_fields([field | rest], "") when is_atom(field), do: stringify_fields(rest, " #{field}")

    # Handles a simple atom field, adding it to the accumulator with a comma separator.
    defp stringify_fields([field | rest], acc) when is_atom(field), do: stringify_fields(rest, "#{acc}, #{field}")

    # Handles a nested field (tuple of type and sub-fields) when the accumulator is empty.
    defp stringify_fields([{type, fields} | rest], ""),
      do: stringify_fields(rest, " #{type} {#{stringify_fields(fields)}}")

    # Handles a nested field, adding it to the accumulator with a comma separator.
    defp stringify_fields([{type, fields} | rest], acc),
      do: stringify_fields(rest, "#{acc}, #{type} {#{stringify_fields(fields)}}")
  end

  defimpl Request, for: ArchethicClient.Graphql do
    alias ArchethicClient.Graphql
    alias ArchethicClient.GraphqlError
    alias ArchethicClient.RequestError

    @doc """
    Determines the type of the GraphQL request.
    Returns `:graphql_query` for queries and `:graphql_subscription` for subscriptions.
    """
    @spec type(request :: Graphql.t()) :: :graphql_query | :graphql_subscription
    def type(%Graphql{type: :query}), do: :graphql_query
    def type(%Graphql{type: :subscription}), do: :graphql_subscription

    @doc """
    Checks if the GraphQL request is a subscription.
    Returns `true` for subscriptions, `false` otherwise.
    """
    @spec subscription?(request :: Graphql.t()) :: boolean()
    def subscription?(%Graphql{type: :subscription}), do: true
    def subscription?(_), do: false

    @doc """
    Generates a unique request ID for the GraphQL request.
    The ID is prefixed with "graphql_" followed by an index.
    """
    @spec request_id(request :: Graphql.t(), index :: non_neg_integer()) :: String.t()
    def request_id(_request, index), do: "graphql_#{index}"

    @doc """
    Formats the body of the GraphQL request.
    Prepends the request ID to the stringified GraphQL request.
    """
    @spec format_body(request :: Graphql.t(), request_id :: String.t()) :: String.t()
    def format_body(%Graphql{} = request, request_id) do
      "#{request_id}: #{to_string(request)}"
    end

    @doc """
    Formats an incoming message (typically from a subscription) related to a GraphQL request.
    Extracts the data associated with the request ID from the message.
    """
    @spec format_message(request :: Graphql.t(), request_id :: String.t(), message :: map()) :: term()
    def format_message(_, request_id, %{"data" => data}), do: Map.get(data, request_id)

    @doc """
    Formats the response received from a GraphQL request.

    For successful queries, it extracts the relevant data or error.
    For successful subscriptions, it returns the body as is.
    For HTTP errors, it returns a `RequestError`.
    """
    @spec format_response(
            request :: Graphql.t(),
            request_id :: String.t(),
            response :: Req.Response.t()
          ) :: {:ok, term()} | {:error, Exception.t()}
    def format_response(%Graphql{type: :query}, request_id, %Req.Response{status: 200, body: %{"data" => data} = body}) do
      errors = Map.get(body, "errors", [])

      case Enum.find(errors, fn %{"path" => path} -> Enum.member?(path, request_id) end) do
        nil ->
          {:ok, Map.get(data, request_id)}

        %{"locations" => [location | _], "message" => message} ->
          {:error, %GraphqlError{message: message, location: location}}
      end
    end

    def format_response(%Graphql{type: :subscription}, _request_id, %Req.Response{status: 200, body: body}),
      do: {:ok, body}

    def format_response(_, _, %Req.Response{status: status, body: body}) do
      {:error, %RequestError{http_status: status, body: body}}
    end
  end
end
