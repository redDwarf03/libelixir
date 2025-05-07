# Ensure our test behaviors are loaded
# Code.require_file("support/behaviors.ex", __DIR__)
ExUnit.start()

# Define mocks using Mox
Mox.defmock(ArchethicClient.APIMock, for: ArchethicClient.Test.Behaviors.API)
Mox.defmock(ArchethicClient.RequestHelperMock, for: ArchethicClient.Test.Behaviors.RequestHelper)
Mox.defmock(ArchethicClient.AsyncHelperMock, for: ArchethicClient.Test.Behaviors.AsyncHelper)

# Configure stubs globally
Mox.stub_with(ArchethicClient.APIMock, ArchethicClient.API)
Mox.stub_with(ArchethicClient.RequestHelperMock, ArchethicClient.RequestHelper)
Mox.stub_with(ArchethicClient.AsyncHelperMock, ArchethicClient.RealAsyncHelper)
