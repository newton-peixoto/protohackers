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
    case :gen_tcp.listen(@port, @socket_options) do
      {:ok, socket} ->
        Logger.info("listening on port #{inspect(@port)}")
        {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)
        state = %__MODULE__{socket: socket, supervisor: supervisor}
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
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

  defp handle_connection(socket) do
    :gen_tcp.send(socket, "What should you be called?\n")

    case :gen_tcp.recv(socket, 0) do
      {:ok, current_user} ->
        current_user = String.trim(current_user)

        all_users = Chat.all_users()

        if String.match?(current_user, ~r/^[a-zA-Z0-9]+$/) do
          all_sockets = Enum.map(all_users, fn {socket, _username} -> socket end)
          usernames = Enum.map_join(all_users, ", ", fn {_socket, username} -> username end)

          Chat.add(current_user, socket)
          Logger.debug("User [#{current_user}] joined.")
          :gen_tcp.send(socket, "* The room contains: #{usernames}\n")

          Enum.each(all_sockets, fn s ->
            :gen_tcp.send(s, "* #{current_user} has entered the room\n")
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

          Enum.each(all_users, fn {s, _u} ->
            if s == socket, do: :ok, else: :gen_tcp.send(s, "[#{current_user}] #{message}\n")
          end)
        end

        handle_messages(socket, current_user)

      {:error, _} ->
        all_users = Chat.all_users()

        Enum.each(all_users, fn {s, _} ->
          if s == socket, do: :ok, else: :gen_tcp.send(s, "* #{current_user} has left the room\n")
        end)

        :gen_tcp.close(socket)
        Chat.delete(socket)
        Logger.debug("User [#{current_user}] left.")
    end
  end
end
