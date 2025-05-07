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
    actual_action = action || ""
    actual_args = args || []

    serialized_args_list = Enum.map(actual_args, &TypedEncoding.serialize/1)
    serialized_args_binary = :erlang.list_to_binary(serialized_args_list)

    <<1::8, address::binary, byte_size(actual_action)::8, actual_action::binary, length(actual_args)::8, serialized_args_binary::binary>>
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
