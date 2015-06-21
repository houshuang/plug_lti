defmodule Grade do
  import PlugLti
  @contents String.strip(File.read!("request.txt"))

  def call(url, sourcedId, score) do
    contents = gen_contents(sourcedId, score)
    param_base = params(contents) 

    signature = ["POST", url, param_base |> proc_params] 
      |> Enum.map(&(URI.encode_www_form/1))
      |> Enum.join("&")
      |> hmac_signature

    param_base = Map.put(param_base, "oauth_signature", signature)

    paramstr = param_base
    |> Enum.map(fn {k, v} -> "#{k}=\"#{param_value(v)}\"" end)
    |> Enum.join(",")

    HTTPoison.request(:post, url , contents, 
      [{:Accept, "application/xml"}, {:Authorization, 
        "OAuth realm=\"\"," <> paramstr}])
    |> IO.inspect # todo - parse response
  end

  def param_value(x) do
    x
    |> PlugLti.ensure_string
    |> URI.encode_www_form
  end

  def params(contents) do
    key = Application.get_env(:plug_lti, :lti_key)
    if !is_binary(key), do: raise PlugLti.MissingSecret

    %{
      "oauth_consumer_key"     => key,
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_version"          => "1.0",
      "oauth_body_hash"        => :crypto.hash(:sha, contents) |> Base.encode64,
      "oauth_timestamp"        => timestamp
    }
  end

  def timestamp do
    {mgsec, sec, _mcs} = :os.timestamp

    mgsec * 1_000_000 + sec
    |> Integer.to_string
  end

  def gen_contents(sourcedId, score) do
    """
    <?xml version="1.0" encoding="UTF-8"?><imsx_POXEnvelopeRequest xmlns="http://www.imsglobal.org/services/ltiv1p1/xsd/imsoms_v1p0"><imsx_POXHeader><imsx_POXRequestHeaderInfo><imsx_version>V1.0</imsx_version><imsx_messageIdentifier>769f985c-5a04-4822-899f-cb34b6454e4a</imsx_messageIdentifier></imsx_POXRequestHeaderInfo></imsx_POXHeader><imsx_POXBody><replaceResultRequest><resultRecord><sourcedGUID><sourcedId>#{sourcedId}</sourcedId></sourcedGUID><result><resultScore><language>en</language><textString>#{score}</textString></resultScore></result></resultRecord></replaceResultRequest></imsx_POXBody></imsx_POXEnvelopeRequest>
    """
    |> String.strip
  end
end
