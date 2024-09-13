defmodule Protohackers.Database.Prices do
  defstruct [:data]

  def new_db() do
    %__MODULE__{
      data: []
    }
  end

  def add(db = %__MODULE__{}, {_timestamp, _price} = row) do
    data = [row | db.data]
    Map.put(db, :data, data)
  end

  def query(db = %__MODULE__{}, from, to) do
    {_, prices} =
      Enum.map_reduce(db.data, [], fn {timestamp, price}, acc ->
        if timestamp >= from and timestamp <= to do
          {nil, [price | acc]}
        else
          {nil, acc}
        end
      end)

    Integer.floor_div(Enum.sum(prices), length(prices))
  end
end
