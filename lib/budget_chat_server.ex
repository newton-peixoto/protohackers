defmodule BudgetChatServer do
  use GenServer
  require Logger
  alias Protohackers.Database.Chat

  defstruct [:socket, :supervisor]
  @moduledoc false

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
          all_sockets = Enum.map(all_users, &elem(&1, 0))
          usernames = Enum.map_join(all_users, ", ", &elem(&1, 1))

          Chat.add(current_user, socket)
          Logger.debug("User [#{current_user}] joined.")
          :gen_tcp.send(socket, "* The room contains: #{usernames}\n")
          send_all_messages(socket, all_sockets, current_user, :joined)

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
          all_sockets = Enum.map(all_users, &elem(&1, 0))
          send_all_messages(socket, all_sockets, current_user, message)
        end

        handle_messages(socket, current_user)

      {:error, _} ->
        all_users = Chat.all_users()
        all_sockets = Enum.map(all_users, &elem(&1, 0))
        send_all_messages(socket, all_sockets, current_user, :left)

        :gen_tcp.close(socket)
        Chat.delete(socket)
        Logger.debug("User [#{current_user}] left.")
    end
  end

  defp send_all_messages(sender, receivers, current_user, :joined) do
    Logger.debug("#{inspect(receivers)}")
    Enum.each(receivers, fn s ->
      send_message(sender, s, "* #{current_user} has entered the room\n")
    end)
  end

  defp send_all_messages(sender, receivers, current_user, :left) do
    Enum.each(receivers, fn s ->
      send_message(sender, s, "* #{current_user} has left the room\n")
    end)
  end

  defp send_all_messages(sender, receivers, current_user, message) do
    Enum.each(receivers, fn s -> send_message(sender, s, "[#{current_user}] #{message}\n") end)
  end

  defp send_message(sender, sender, _), do: :ok

  defp send_message(_sender, receiver, message),
    do: :gen_tcp.send(receiver, message)
end
