PlugLti
=======

This is a first attempt at a [Plug]() for Elixir for [LTI]() tool providers. Currently, it only provides verification of the OAuth header signature, which ensures that the request comes from the right client. I am thinking about how to support working with the parameters, and submitting grades back. 

It has only been tested on EdX, but I'm happy to accept pull requests for other platforms, with matching tests. For the tests, please capture an authentic conn from an LTI consumer, and insert the relevant parts into the test file (as my example). 

If you want to use this in Phoenix, use add :plug PlugLti in the pipeline for the relevant pages, and add the LTI secret to the config.exs file:

:config LtiSecret,
    :lti_secret: "secret"

If the signature matches, the request will be passed through and can be handled by you as normally. If not, the plug will send a response of Forbidden, with the text "Missing or mismatched OAuth signature in header", and log an info message with the reason (either missing signature, or signature mismatch).

Comments/pull requests around style/idiomatic code also welcome.
