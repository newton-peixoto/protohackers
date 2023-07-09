defmodule PrimeServerTest do
  use ExUnit.Case, async: true

  test "it echoes back expected response" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5002, mode: :binary, active: false)
    :gen_tcp.send(socket, Jason.encode!(%{method: "isPrime", number: 5}) <> "\n")

    assert {:ok, data} = :gen_tcp.recv(socket, 0, 5000)
    assert String.ends_with?(data, "\n")
    assert Jason.decode!(data) == %{"method" => "isPrime", "prime" => true}

    :gen_tcp.send(socket, Jason.encode!(%{method: "isPrime", number: 100}) <> "\n")

    assert {:ok, data} = :gen_tcp.recv(socket, 0, 5000)
    assert String.ends_with?(data, "\n")
    assert Jason.decode!(data) == %{"method" => "isPrime", "prime" => false}

    :gen_tcp.send(socket, Jason.encode!(%{method: "not_allowed", number: 100}) <> "\n")

    assert {:ok, data} = :gen_tcp.recv(socket, 0, 5000)
    assert String.ends_with?(data, "\n")
    assert data == "malformed request\n"
  end
end
