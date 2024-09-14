defmodule BudgetChatServerTest do
  use ExUnit.Case, async: true

  test "it should work as expected flow" do
    {:ok, socket1} = :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false)
    {:ok, socket2} = :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false)

    assert {:ok, "What should you be called?\n"} == :gen_tcp.recv(socket1, 0)
    assert {:ok, "What should you be called?\n"} == :gen_tcp.recv(socket2, 0)

    :ok = :gen_tcp.send(socket1, "Socket1\n")
    assert {:ok, "* The room contains: \n"} == :gen_tcp.recv(socket1, 0)
    :ok = :gen_tcp.send(socket2, "Socket2\n")
    assert {:ok, "* The room contains: Socket1\n"} == :gen_tcp.recv(socket2, 0)

    :ok = :gen_tcp.send(socket1, "Oi Socket2\n")
    assert {:ok, "[Socket1] Oi Socket2\n"} == :gen_tcp.recv(socket2, 0)

    assert {:ok, "* Socket2 has entered the room\n"} == :gen_tcp.recv(socket1, 0)
    :ok = :gen_tcp.send(socket2, "Oi Socket1\n")
    assert {:ok, "[Socket2] Oi Socket1\n"} == :gen_tcp.recv(socket1, 0)

    :gen_tcp.close(socket1)
    assert {:ok, "* Socket1 has left the room\n"} == :gen_tcp.recv(socket2, 0)

    {:ok, socket3} = :gen_tcp.connect(~c"localhost", 5004, mode: :binary, active: false)
    assert {:ok, "What should you be called?\n"} == :gen_tcp.recv(socket3, 0)

    :ok = :gen_tcp.send(socket3, "Socket3\n")
    assert {:ok, "* The room contains: Socket2\n"} == :gen_tcp.recv(socket3, 0)
  end
end
