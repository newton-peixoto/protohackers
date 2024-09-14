defmodule MeanToEnd do
  alias Protohackers.Database.Prices
  use GenServer
  require Logger

  defstruct [:socket, :supervisor]

  @port 5003

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
    Logger.info("listening on port #{inspect(@port)}")
    # handle concurrent connection on different processes
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 5)
    state = %__MODULE__{socket: socket, supervisor: supervisor}
    {:ok, state, {:continue, :accept}}
  end

  defp listen_socket({:error, reason}), do: {:stop, reason}

  defp accept_connection({:ok, socket}, state) do
    Task.Supervisor.start_child(state.supervisor, fn ->
      handle_connection(socket, Prices.new_db())
    end)

    {:noreply, state, {:continue, :accept}}
  end

  defp accept_connection({:error, reason}, _state), do: {:stop, reason}

  defp handle_connection(socket, db) do
    case :gen_tcp.recv(socket, 9, 10_000) do
      {:ok, data} when byte_size(data) == 9 ->
        handle_message(socket, db, data)
        :gen_tcp.send(socket, data)

      {:error, _} ->
        :gen_tcp.close(socket)
    end
  end

  defp handle_message(socket, db, <<?I, timestamp::32-signed-big, price::32-signed-big>>) do
    Logger.info("Inserting at  #{timestamp} costing #{price}")
    db = Prices.add(db, {timestamp, price})
    handle_connection(socket, db)
  end

  defp handle_message(socket, db, <<?Q, from::32-signed-big, to::32-signed-big>>) do
    Logger.info("Querying from  #{from} to #{to}")
    median = Prices.query(db, from, to)
    :gen_tcp.send(socket, <<median::32-signed-big>>)
    handle_connection(socket, db)
  end
end
