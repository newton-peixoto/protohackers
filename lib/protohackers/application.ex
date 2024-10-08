defmodule Protohackers.Application do
  use Application

  @moduledoc false

  @impl true
  def start(_type, _args) do
    children = [
      {EchoServer, []},
      {PrimeServer, []},
      {MeanToEnd, []},
      {Protohackers.Database.Chat, []},
      {BudgetChatServer, []}
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
