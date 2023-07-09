defmodule PrimeServer do
  use GenServer
  require Logger

  defstruct [:socket, :supervisor]

  @port 5002

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

  # GENSERVER CALLBACKS

  @impl true
  def init(_opts) do
    listen_socket(:gen_tcp.listen(@port, @socket_options))
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state),
    do: accept_connection(:gen_tcp.accept(state.socket), state)

  # PRIVATE FUNCTIONS

  defp listen_socket({:ok, socket}) do
    Logger.info("Listen on port #{inspect(@port)}")
    # handle concurrent connection on different processes
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 5)
    state = %__MODULE__{socket: socket, supervisor: supervisor}
    {:ok, state, {:continue, :accept}}
  end

  defp listen_socket({:error, reason}), do: {:stop, reason}

  defp accept_connection({:ok, socket}, state) do
    Task.Supervisor.start_child(state.supervisor, fn -> handle_connection(socket) end)
    {:noreply, state, {:continue, :accept}}
  end

  defp accept_connection({:error, reason}, _state), do: {:stop, reason}

  defp handle_connection(socket) do
    read_line(:gen_tcp.recv(socket, 0, 10_000), socket)
    :gen_tcp.close(socket)
  end

  defp read_line({:ok, data}, socket), do: handle_line(Jason.decode(data), socket)
  defp read_line({:error, :closed}, _socket), do: :ok

  defp read_line({:error, reason}, _socket),
    do: Logger.error("Failed to receive data: #{inspect(reason)}")

  defp handle_line({:ok, %{"method" => "isPrime", "number" => number}}, socket)
       when is_number(number) do
    response = %{method: "isPrime", prime: is_prime?(number)}
    :gen_tcp.send(socket, Jason.encode!(response) <> "\n")
    read_line(:gen_tcp.recv(socket, 0, 10_000), socket)
  end

  defp handle_line(error, socket) do
    Logger.error("Received invalid request: #{inspect(error)}")
    :gen_tcp.send(socket, "malformed request\n")
    {:error, :invalid_request}
  end

  defp is_prime?(n) when n < 2, do: false
  defp is_prime?(n) when is_float(n), do: false
  defp is_prime?(n) when n in [2, 3], do: true

  defp is_prime?(n) do
    not Enum.any?(2..trunc(:math.sqrt(n)), &(rem(n, &1) == 0))
  end
end
