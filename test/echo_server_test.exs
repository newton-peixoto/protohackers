defmodule EchoServerTest do
  use ExUnit.Case

  test "it should send anything back to the client" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 5001, mode: :binary, active: false)

    assert :gen_tcp.send(socket, "foo") == :ok
    assert :gen_tcp.send(socket, "foo2") == :ok

    :gen_tcp.shutdown(socket, :write)

    assert :gen_tcp.recv(socket, 0) == {:ok, "foofoo2"}
  end
end
