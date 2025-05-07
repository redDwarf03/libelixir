import Config

config :archethic_client, :enable_mock?, true
config :archethic_client, :base_url, "http://localhost:4000"

# Set custom paths for mock implementations
config :archethic_client,
  api_module: ArchethicClient.APIMock,
  request_helper_module: ArchethicClient.RequestHelperMock
