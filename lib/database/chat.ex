defmodule Protohackers.Database.Chat do
  use GenServer

  def start_link(_opts) do
    GenServer.start(__MODULE__, %{}, name: __MODULE__)
  end

  def all_users() do
    GenServer.call(__MODULE__, :all_users)
  end

  def add(username, socket) do
    GenServer.call(__MODULE__, {:add, {username, socket}})
  end

  def delete(socket) do
    GenServer.cast(__MODULE__, {:delete, socket})
  end


  # Call backs
  @impl true
  def init(users = %{}) do
    {:ok, users}
  end

  @impl true
  def handle_call(:all_users, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add, {username, socket}}, _from, state) do
    state = Map.put(state, username, socket)
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:delete, socket}, state) do
    state = Map.reject(state, fn {_, val } -> val == socket end )
    {:noreply, state}
  end
end
