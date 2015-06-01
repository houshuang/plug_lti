defmodule PlugLti do
  @moduledoc """
  A Plug to verify signed LTI requests. Currently only tested on EdX, pull
  requests to make it work with other services, with tests, are welcome. 
  
  Configure the LTI secret in the mix config file, for example
      
      config :plug_lti,
        lti_secret: "secret"
  """

  use Behaviour
  @behaviour Plug
  import Plug.Conn

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
      "#{env}#{full_path(conn)}"
    else
      port_repr = case {scheme, port} do
        {:http, 80} -> ""
        {:https, 443} -> ""
        {_, port} -> ":#{port}"
      end

      "#{scheme}://#{host}#{port_repr}#{full_path(conn)}"
    end
  end

  def call(conn, _) do
    try do
      signature = conn 
        |> fetch_query_params
        |> ensure_has_signature
        |> signature_base_string
        |> hmac_signature
      
      # assert that signature provided equals signature calculated
      if signature != conn.params["oauth_signature"], do:
        raise SignatureMismatch
      conn

    rescue 
      e in [NoSignature, SignatureMismatch] -> 
      Logger.info "PlugLti: " <> Exception.message(e)
      conn
        |> put_resp_header("content-type", "text/plain; charset=utf-8")
        |> send_resp(Plug.Conn.Status.code(:forbidden), 
          "Missing or mismatched OAuth signature in header")
        |> halt

      e in [MissingSecret] -> 
        Logger.info "PlugLti: " <> Exception.message(e)
        halt(conn)

     e -> raise e
    end
  end

  def ensure_has_signature(conn = %Plug.Conn{params: %{"oauth_signature" => _}}), do: conn
  def ensure_has_signature(_), do: raise NoSignature
  
  def hmac_signature(str) do
    secret = Application.get_env(:plug_lti, :lti_secret)
    if !is_binary(secret), do: raise MissingSecret
    :crypto.hmac(:sha, secret <> "&", str)
      |> Base.encode64
  end

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
      |> Enum.sort 
      |> Enum.map(fn({param, value}) -> 
          "#{URI.encode_www_form( param )}=#{URI.encode_www_form( value )}" 
        end) 
      |> Enum.join("&")
  end
end 
