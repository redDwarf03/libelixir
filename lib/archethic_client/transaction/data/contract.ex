defmodule ArchethicClient.TransactionData.Contract do
  @moduledoc """
  Represents the definition of a smart contract within a transaction.

  A contract is primarily defined by its:
  - `bytecode`: The compiled WebAssembly (WASM) code of the contract.
  - `manifest`: A map describing the contract's functions, state, and upgrade options (ABI).

  This module provides functions to serialize and deserialize contract data, as well as
  convert it to and from map representations.
  """
  alias ArchethicClient.Transaction
  alias ArchethicClient.Utils.TypedEncoding

  @enforce_keys [:bytecode, :manifest]
  defstruct [:bytecode, :manifest]

  @type t :: %__MODULE__{
          bytecode: binary(),
          manifest: map()
        }

  @doc """
  Serialize a contract
  """
  @spec serialize(
          contract :: t(),
          version :: pos_integer()
        ) :: bitstring()
  def serialize(contract, version)

  def serialize(%__MODULE__{bytecode: bytecode, manifest: manifest}, _version) do
    <<byte_size(bytecode)::32, bytecode::binary, TypedEncoding.serialize(manifest)::bitstring>>
  end

  @doc """
  Deserialize a contract
  """
  @spec deserialize(
          rest :: bitstring(),
          version :: pos_integer(),
          serialization_mode :: Transaction.serialization_mode()
        ) :: {t(), bitstring()}
  def deserialize(binary, version, serialization_mode \\ :compact)

  def deserialize(<<bytecode_size::32, bytecode::binary-size(bytecode_size), rest::bitstring>>, _, serialization_mode) do
    {manifest, rest} = TypedEncoding.deserialize(rest, serialization_mode)

    {%__MODULE__{bytecode: bytecode, manifest: manifest}, rest}
  end

  @doc """
  Casts a map or nil into a `ArchethicClient.TransactionData.Contract` struct.

  If nil is provided, nil is returned.
  If a map with `:bytecode` and `:manifest` keys is provided, a struct is returned.
  Useful for creating a struct from parsed data.
  """
  @spec cast(data :: any()) :: nil | t() | {:error, :invalid_contract_input_map}
  def cast(nil), do: nil

  def cast(%{bytecode: bytecode, manifest: manifest}) when is_binary(bytecode) and is_map(manifest) do
    %__MODULE__{bytecode: bytecode, manifest: manifest}
  end

  def cast(_other), do: {:error, :invalid_contract_input_map}

  @doc """
  Converts a `ArchethicClient.TransactionData.Contract` struct or nil into a map representation.

  If nil is provided, nil is returned.
  The bytecode is Base16 encoded in the resulting map.
  The manifest structure is preserved, with specific handling for `upgradeOpts`.
  """
  @spec to_map(contract :: nil | t()) :: nil | map()
  def to_map(nil), do: nil

  def to_map(%__MODULE__{bytecode: bytecode, manifest: manifest}) do
    %{"functions" => functions, "state" => state} = Map.get(manifest, "abi")

    upgrade_opts =
      case Map.get(manifest, "upgradeOpts") do
        %{"from" => from} -> %{from: from}
        nil -> nil
      end

    %{
      bytecode: Base.encode16(bytecode),
      manifest: %{
        abi: %{functions: functions, state: state},
        upgrade_opts: upgrade_opts
      }
    }
  end
end
