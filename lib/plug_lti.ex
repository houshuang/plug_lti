defmodule PlugLti do
  @moduledoc """
  A Plug to verify signed LTI requests. Currently only tested on EdX, pull
  requests to make it work with other services, with tests, are welcome. 
  
  Configure the LTI secret in the mix config file, for example
      
      config :plug_lti,
        lti_secret: "secret"

  Note that LTI requests are received as POST, and this plug transforms them into GET.
  This is to work better with the protect_from_forgery plug, which otherwise would
  except an initial LTI request to have an csrf token.
  """

  use Behaviour
  @behaviour Plug
  alias Plug.Conn

  require Logger

  defmodule MissingSecret, do:
    defexception message: "no valid signature loaded from config file"

  defmodule SignatureMismatch, do:
    defexception message: "provided oauth signature did not match calculated signature"

  defmodule NoSignature, do:
    defexception message: "no oauth signature provided"

  @exclude_params ["format", "oauth_signature"]

  def init([]), do: []

  defp req_url(%Plug.Conn{scheme: scheme, host: host, port: port} = conn) do
    if env = Application.get_env(:plug_lti, :base_url) do
      "#{env}#{conn.request_path}"
    else
      port_repr = case {scheme, port} do
        {:http, 80} -> ""
        {:https, 443} -> ""
        {_, port} -> ":#{port}"
      end

      "#{scheme}://#{host}#{port_repr}#{conn.request_path}"
    end
  end

  def call(conn, _) do
    if Application.get_env(:plug_lti, :plug_disabled) do
      Logger.warn("LTI signature verification disabled")
      conn
    else
      verify_signature(conn)
    end
  end

  def verify_signature(conn) do
    try do
      signature = conn 
        |> Conn.fetch_query_params
        |> ensure_has_signature
        |> signature_base_string
        |> hmac_signature
      
      # assert that signature provided equals signature calculated
      if signature != conn.params["oauth_signature"], do: raise SignatureMismatch

      %{conn | method: "GET"}

    rescue 
      e in [NoSignature, SignatureMismatch] -> 
      Logger.info "PlugLti: " <> Exception.message(e)
      conn
        |> Conn.put_resp_header("content-type", "text/plain; charset=utf-8")
        |> Conn.send_resp(Plug.Conn.Status.code(:forbidden), 
          "Missing or mismatched OAuth signature in header")
        |> Conn.halt

      e in [MissingSecret] -> 
        Logger.info "PlugLti: " <> Exception.message(e)
        Conn.halt(conn)

     e -> raise e
    end
  end

  def ensure_has_signature(conn = %Plug.Conn{params: %{"oauth_signature" => _}}), do: conn
  def ensure_has_signature(_), do: raise NoSignature
  
  def hmac_signature(str) do
    secret = Application.get_env(:plug_lti, :lti_secret)
    if !is_binary(secret), do: raise MissingSecret
    :crypto.hmac(:sha, secret <> "&", str) |> Base.encode64 end 
  def signature_base_string(conn) do
    method = "POST"
    url = req_url(conn)
    params = proc_params(conn.params)

    [method, url, params] 
      |> Enum.map(&(URI.encode_www_form/1))
      |> Enum.join("&")
  end

  def proc_params(params) do
    params
      |> Enum.filter(&(!Enum.member?(@exclude_params, elem(&1, 0))))
      |> Enum.map(fn({param, value}) -> 
          "#{URI.encode_www_form( ensure_string(param) )}=#{
            URI.encode_www_form( ensure_string(value ))}" 
        end) 
      |> Enum.sort 
      |> Enum.join("&")
  end

  def ensure_string(x) when is_integer(x), do: Integer.to_string(x)
  def ensure_string(x) when is_float(x), do: Float.to_string(x)
  def ensure_string(x) when is_binary(x), do: x

end 
