defmodule PlugLtiTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Plug.Conn.Status

  @opts PlugLti.init([])

  test "connections without oauth headers are blocked" do
    # Create a test connection
    conn = conn(:get, "/")

    # Invoke the plug
    response = PlugLti.call(conn, @opts)
    assert response.status == Status.code(:forbidden)
    assert response.resp_body == "Missing or mismatched OAuth signature in header"
  end

end
