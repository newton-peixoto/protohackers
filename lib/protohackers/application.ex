defmodule Protohackers.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {EchoServer, []}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
