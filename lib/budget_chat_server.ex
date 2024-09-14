defmodule BudgetChatServer do
  use GenServer
  require Logger
  alias Protohackers.Database.Chat

  defstruct [:socket, :supervisor]

  @port 5004

  @socket_options [
    ifaddr: {0, 0, 0, 0},
    mode: :binary,
    active: false,
    reuseaddr: true,
    exit_on_close: false,
    packet: :line,
    buffer: 1024 * 100
  ]

  def start_link(opts) do
    GenServer.start(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    listen_socket(:gen_tcp.listen(@port, @socket_options))
  end

  defp listen_socket({:ok, socket}) do
    Logger.info("listening on port #{inspect(@port)}")
    # handle concurrent connection on different processes
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 10)
    state = %__MODULE__{socket: socket, supervisor: supervisor}
    {:ok, state, {:continue, :accept}}
  end

  defp listen_socket({:error, reason}), do: {:stop, reason}

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

  defp handle_connection(socket) do
    :gen_tcp.send(socket, "What should you be called?\n")

    case :gen_tcp.recv(socket, 0) do
      {:ok, current_user} ->
        current_user = String.trim(current_user)

        if String.match?(current_user, ~r/^[a-zA-Z0-9]+$/) do
          Chat.add(current_user, socket)

          all_users = Chat.all_users()
          all_sockets = Enum.map(all_users, fn {_username, socket} -> socket end)

          usernames =
            Enum.filter(all_users, fn {_, s} -> s != socket end)
            |> Enum.map_join(", ", fn {username, _socket} -> username end)

          :gen_tcp.send(socket, "* The room contains: #{usernames}\n")

          Enum.each(all_sockets, fn s ->
            if s == socket,
              do: :ok,
              else: :gen_tcp.send(s, "* #{current_user} has entered the room\n")
          end)

          handle_messages(socket, current_user)
        else
          :gen_tcp.send(socket, "Oops invalid name given\n")
          :gen_tcp.close(socket)
        end

      {:error, _} ->
        :gen_tcp.close(socket)
    end
  end

  defp handle_messages(socket, current_user) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, message} ->
        message = String.trim(message)

        if message != "" do
          all_users = Chat.all_users()

          Enum.each(all_users, fn {_u, s} ->
            if s == socket, do: :ok, else: :gen_tcp.send(s, "[#{current_user}] #{message}\n")
          end)
        end

        handle_messages(socket, current_user)

      {:error, _} ->
        all_users = Chat.all_users()
        Enum.each(all_users, fn {_, s} ->
          if s == socket, do: :ok, else: :gen_tcp.send(s, "* #{current_user} has left the room\n")
        end)
        :gen_tcp.close(socket)
        Chat.delete(socket)
    end
  end
end
