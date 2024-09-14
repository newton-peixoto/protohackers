defmodule Protohackers.Database.Prices do
  defstruct [:data]
  @moduledoc false
  def new_db() do
    %__MODULE__{
      data: []
    }
  end

  def add(%__MODULE__{} = db, {_timestamp, _price} = row) do
    data = [row | db.data]
    Map.put(db, :data, data)
  end

  def query(%__MODULE__{} = db, from, to) do
    Enum.map_reduce(db.data, {0, 0}, fn {timestamp, price}, {count, sum} ->
      if timestamp >= from and timestamp <= to do
        {nil, {count + 1, sum + price}}
      else
        {nil, {count, sum}}
      end
    end)
    |> then(fn
      {_, {0, _price}} -> 0
      {_, {count, price}} -> div(price, count)
    end)
  end
end
