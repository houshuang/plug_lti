ExUnit.start()

defmodule AppMaker do
  defmacro __using__(options) do
    quote do
      use Plug.Router
      alias Plug.Conn.Status

      plug PlugRequireHeader, unquote(options)
      plug :match
      plug :dispatch
    end
  end
end
