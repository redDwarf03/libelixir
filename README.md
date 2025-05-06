# ArchethicClient

ArchethicClient is an Elixir library for interacting with the [Archethic blockchain](https://www.archethic.net/). It provides a high-level, easy-to-use interface for sending requests, managing transactions, querying balances, and interacting with smart contracts on the Archethic network.

## Features

- Send single or batch requests to the Archethic network
- Query the balance of a genesis address
- Call public functions on smart contracts
- Retrieve the chain index for an address
- Send transactions with confirmation/error handling
- Synchronous API with both error-tuple and bang (`!`) variants
- Modular design for extensibility

## Installation

Add `archethic_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:archethic_client, "~> 0.1.1"}
  ]
end
```

Then run:

```sh
mix deps.get
```

## Usage

Import the main module in your Elixir code:

```elixir
alias ArchethicClient
```

### Send a Request

```elixir
request = ArchethicClient.RequestHelper.get_balance("GENESIS_ADDRESS")
{:ok, response} = ArchethicClient.request(request)
```

### Batch Requests

```elixir
requests = [
  ArchethicClient.RequestHelper.get_balance("GENESIS_ADDRESS_1"),
  ArchethicClient.RequestHelper.get_balance("GENESIS_ADDRESS_2")
]
results = ArchethicClient.batch_requests(requests)
```

### Get Balance

```elixir
{:ok, balance} = ArchethicClient.get_balance("GENESIS_ADDRESS")
# Or raise on error
balance = ArchethicClient.get_balance!("GENESIS_ADDRESS")
```

### Call a Contract Function

```elixir
{:ok, result} = ArchethicClient.call_contract_function("CONTRACT_ADDRESS", "function_name", [arg1, arg2])
# Or raise on error
result = ArchethicClient.call_contract_function!("CONTRACT_ADDRESS", "function_name", [arg1, arg2])
```

### Get Chain Index

```elixir
{:ok, index} = ArchethicClient.get_chain_index("ADDRESS")
# Or raise on error
index = ArchethicClient.get_chain_index!("ADDRESS")
```

### Send a Transaction

```elixir
transaction = %ArchethicClient.Transaction{address: <<...>>, ...}
:ok = ArchethicClient.send_transaction(transaction)
```

## Documentation

Full documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc):

```sh
mix docs
```

Once published, the docs will be available at [HexDocs](https://hexdocs.pm/archethic_client).

## Development

- Elixir >= 1.13 is required.
- Main dependencies: [req](https://hex.pm/packages/req), [absinthe_client](https://github.com/Neylix/absinthe_client), [decimal](https://hex.pm/packages/decimal)
- Development tools: [credo](https://hex.pm/packages/credo), [dialyxir](https://hex.pm/packages/dialyxir), [styler](https://hex.pm/packages/styler)

To run tests:

```sh
mix test
```

## Contributing

Contributions are welcome! Please open issues or submit pull requests on GitHub.

## License

This project is licensed under the terms of the LICENSE file in this repository.
