defmodule EchoServer do
  use GenServer
  require Logger

  defstruct [:socket, :supervisor]

  @port 5001

  @socket_options [
    ifaddr: {0, 0, 0, 0},
    mode: :binary,
    active: false,
    reuseaddr: true,
    exit_on_close: false
  ]

  def start_link(opts) do
    GenServer.start(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    listen_socket(:gen_tcp.listen(@port, @socket_options))
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(state.supervisor, fn -> handle_connection(socket) end)
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  ## Helpers

  defp handle_connection(socket) do
    case recv_until_closed(socket, _buffer = "") do
      {:ok, data} -> :gen_tcp.send(socket, data)
      {:error, reason} -> Logger.error("Failed to receive data: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  # VULNERABILITY SINCE WE'RE NOT LIMITING A AMOUNT OF DATA -> fix creating a max buffer size guard
  defp recv_until_closed(socket, buffer) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} -> recv_until_closed(socket, [buffer, data])
      {:error, :closed} -> {:ok, buffer}
      {:error, reason} -> {:error, reason}
    end
  end

  def listen_socket({:ok, socket}) do
    Logger.info("Listen on port #{inspect(@port)}")
    # handle concurrent connection on different processes
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 5)
    state = %__MODULE__{socket: socket, supervisor: supervisor}
    {:ok, state, {:continue, :accept}}
  end

  def listen_socket({:error, reason}), do: {:stop, reason}
end
