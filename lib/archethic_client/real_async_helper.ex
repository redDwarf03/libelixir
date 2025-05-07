defmodule ArchethicClient.RealAsyncHelper do
  @moduledoc """
  Real implementation of the AsyncHelper behaviour, calling actual Task functions.
  """

  if Mix.env() == :test do
    @behaviour ArchethicClient.Test.Behaviors.AsyncHelper
  end

  def async_nolink(supervisor_name, fun) do
    Task.Supervisor.async_nolink(supervisor_name, fun)
  end

  def async_stream_nolink(supervisor_name, inputs, fun, opts) do
    Task.Supervisor.async_stream_nolink(supervisor_name, inputs, fun, opts)
  end

  def yield(task, timeout) do
    Task.yield(task, timeout)
  end

  def shutdown(task, reason_or_timeout) do
    Task.shutdown(task, reason_or_timeout)
  end
end
