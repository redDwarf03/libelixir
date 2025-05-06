defmodule ArchethicClient.TransactionData.Recipient do
  @moduledoc """
  Represents a recipient of a transaction, typically for smart contract interactions.

  A recipient record specifies:
  - `address`: The address of the target smart contract.
  - `action`: The name of the function (action) to be called on the smart contract. Can be `nil`.
  - `args`: A list of arguments to be passed to the smart contract function. Can be `nil`.

  The `action` and `args` fields might be `nil` if the transaction itself is the trigger
  (e.g., a simple transfer to a contract address that has a default payable/receive function),
  or they are filled when a specific function with arguments is being invoked.
  """
  alias ArchethicClient.Crypto
  alias ArchethicClient.Utils.TypedEncoding

  defstruct [:address, :action, :args]

  @type t :: %__MODULE__{
          address: Crypto.address(),
          action: String.t() | nil,
          args: list(any()) | nil
        }

  @doc """
  Serialize a recipient
  """
  @spec serialize(recipient :: t()) :: binary()
  def serialize(%__MODULE__{address: address, action: action, args: args}) do
    serialized_args = args |> Enum.map(&TypedEncoding.serialize/1) |> :erlang.list_to_binary()

    <<1::8, address::binary, byte_size(action)::8, action::binary, length(args)::8, serialized_args::binary>>
  end

  @doc """
  Converts a `Recipient` struct into a map representation.

  The `address` field is Base16 encoded in the resulting map.
  The `action` and `args` fields are included as is.
  """
  @spec to_map(recipient :: t()) :: map()
  def to_map(%__MODULE__{address: address, action: action, args: args}),
    do: %{address: Base.encode16(address), action: action, args: args}
end
