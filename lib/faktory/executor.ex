defmodule Faktory.Executor do
  @moduledoc false
  use GenServer
  alias Faktory.{Logger, Utils}

  def start_link(worker, middleware) do
    GenServer.start_link(__MODULE__, {worker, middleware})
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:run, job}, {worker, middleware}) do
    try do
      perform(job, middleware) # Eventually calls dispatch.
    rescue
      error -> handle_error(error, worker)
    end

    {:stop, :normal, nil}
  end

  defp perform(job, middleware) do
    Logger.debug "running job #{inspect(job)}"
    traverse_middleware(job, middleware)
  end

  def dispatch(job) do
    module = Module.safe_concat(Elixir, job["jobtype"])
    apply(module, :perform, job["args"])
  end

  defp handle_error(error, worker) do
    errtype = Utils.module_name(error.__struct__)
    message = Exception.message(error)
    trace = Exception.format_stacktrace(System.stacktrace)
    error = {errtype, message, trace}
    :ok = GenServer.call(worker, {:error_report, error})
  end

  def traverse_middleware(job, []) do
    dispatch(job)
    job
  end

  def traverse_middleware(job, [middleware | chain]) do
    middleware.call(job, chain, &traverse_middleware/2)
  end

end
