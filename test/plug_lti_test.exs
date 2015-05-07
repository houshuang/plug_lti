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

  test "correct signature is allowed" do
    conn = conn(:post, "/select_groups")
    conn = %{conn |host: "127.0.0.1", method: "POST",
      params: %{"context_id" => "UniversityOfTorontoX/INQ101/2014",
        "format" => "html", "launch_presentation_return_url" => "",
        "lis_result_sourcedid" => "UniversityOfTorontoX/INQ101/2014:-i4x-UniversityOfTorontoX-INQ101-lti-aae48eefc4c841de8f002e80e490b587:student",
        "lti_message_type" => "basic-lti-launch-request", "lti_version" => "LTI-1p0",
        "oauth_callback" => "about:blank", "oauth_consumer_key" => "test",
        "oauth_nonce" => "68716679400714828901430994129",
        "oauth_signature" => "GsW2vawv2molo3Lad7uJ8i8NSYw=",
        "oauth_signature_method" => "HMAC-SHA1", "oauth_timestamp" => "1430994129",
        "oauth_version" => "1.0",
        "resource_link_id" => "-i4x-UniversityOfTorontoX-INQ101-lti-aae48eefc4c841de8f002e80e490b587",
        "roles" => "Instructor", "user_id" => "student"},
      path_info: ["select_group"], port: 4000}

    # Invoke the plug
    response = PlugLti.call(conn, @opts)
    assert response.status == nil
    assert response.resp_body == nil
  end

  test "slightly wrong signature is not allowed" do
    conn = conn(:post, "/select_groups")
    conn = %{conn |host: "127.0.0.1", method: "POST",
      params: %{"context_id" => "UniversityOfTorontoX/INQ101/2014",
        "format" => "html", "launch_presentation_return_url" => "",
        "lis_result_sourcedid" => "UniversityOfTorontoX/INQ101/2014:-i4x-UniversityOfTorontoX-INQ101-lti-aae48eefc4c841de8f002e80e490b587:student",
        "lti_message_type" => "basic-lti-launch-request", "lti_version" => "LTI-1p0",
        "oauth_callback" => "about:blank", "oauth_consumer_key" => "test",
        "oauth_nonce" => "68716679400714828901430994129",
        "oauth_signature" => "GsW2vawv2Molo3Lad7uJ8i8NSYw=",
        "oauth_signature_method" => "HMAC-SHA1", "oauth_timestamp" => "1430994129",
        "oauth_version" => "1.0",
        "resource_link_id" => "-i4x-UniversityOfTorontoX-INQ101-lti-aae48eefc4c841de8f002e80e490b587",
        "roles" => "Instructor", "user_id" => "student"},
      path_info: ["select_group"], port: 4000}

    # Invoke the plug
    response = PlugLti.call(conn, @opts)
    assert response.status == Status.code(:forbidden)
    assert response.resp_body == "Missing or mismatched OAuth signature in header"
  end
end
