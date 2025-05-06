defmodule ArchethicClient.APITest do
  @moduledoc """
  Provides utilities for mocking `Req` HTTP requests during testing of the Archethic API client.

  This module allows defining stubbed responses for HTTP requests, making it possible
  to test API interactions without making actual network calls. It integrates with `Req.Test`.
  """
  alias ArchethicClient.Crypto

  @doc """
  Stub request
  """
  @spec stub(callback :: function()) :: :ok
  def stub(callback) do
    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 200, :erlang.term_to_binary(callback))
    end)
  end

  @doc """
  A `Req.Test` plug callback used as the `:into` option to process the stubbed response data.

  It decodes the term-to-binary data (which is a callback function provided to `stub/1`)
  and then applies this callback to the original request(s) stored in `Req.Request`'s private data.
  This allows the test to dynamically generate a response based on the request being mocked.

  The `req` and `resp` arguments are part of the `Req.Test` plug interface.
  `{:data, data}` is the term returned by the stub function defined in `stub/1`.
  """
  def parse_resp({:data, data}, {req, resp}) do
    callback = :erlang.binary_to_term(data)

    body = req |> Req.Request.get_private(:archethic_client) |> create_resp_body(callback)

    resp = %Req.Response{resp | body: body}

    {:cont, {req, resp}}
  end

  # Creates the response body by applying the callback to the request or list of requests.
  # Used by `parse_resp/2`.
  defp create_resp_body(requests, callback) when is_list(requests), do: Enum.map(requests, &callback.(&1))
  defp create_resp_body(request, callback), do: callback.(request)

  @doc """
  Return a random address and format it
  """
  @spec random_address(format :: :binary | :hex) :: Crypto.address() | Crypto.hex_address()
  def random_address(format \\ :binary) when format in [:binary, :hex] do
    address = <<0::16, :crypto.strong_rand_bytes(32)::binary>>
    if format == :hex, do: Base.encode16(address), else: address
  end
end
