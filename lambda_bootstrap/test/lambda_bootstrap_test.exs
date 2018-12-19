defmodule LambdaBootstrapTest do
  use ExUnit.Case
  doctest LambdaBootstrap

  @base_url 'http://lambdahost/2018-06-01'
  @request_id '--request-id--'

  defmodule HttpcMock do

    def request(:get, {'http://lambdahost/2018-06-01/runtime/invocation/next', []}, [], []),
      do: {:ok,
            {{'HTTP/1.1', 200, 'OK'},
            [
              {'Lambda-Runtime-Aws-Request-Id', '--request-id--'}
            ],  """
                {
                  "path": "/test/hello",
                  "headers": {
                    "X-Forwarded-Proto": "https"
                  },
                  "pathParameters": {
                    "proxy": "hello"
                  },
                  "requestContext": {
                    "accountId": "123456789012",
                    "resourceId": "us4z18",
                    "stage": "test",
                    "requestId": "41b45ea3-70b5-11e6-b7bd-69b5aaebc7d9",
                    "identity": {
                      "cognitoIdentityPoolId": ""
                    },
                    "resourcePath": "/{proxy+}",
                    "httpMethod": "GET",
                    "apiId": "wt6mne2s9k"
                  },
                  "resource": "/{proxy+}",
                  "httpMethod": "GET",
                  "queryStringParameters": {
                    "name": "me"
                  },
                  "stageVariables": {
                    "stageVarName": "stageVarValue"
                  }
                }
                """}}

    def request(:post,
                {'http://lambdahost/2018-06-01/runtime/invocation/--request-id--/response',
                 [], "application/json", body}, [], []),
      do: {:ok, body}

    def request(:post, {'http://lambdahost/2018-06-01/runtime/invocation/--request-id--/error', [], "application/json", body}, [], []),
      do: {:ok, body}

  end

  def hello_world(event, context), do: {:ok, %{ :message => "Hello Elixir" }}

  test "Handling an event" do
    assert LambdaBootstrap.handle_request(HttpcMock, @base_url, &hello_world/2) == {:ok, "{\"message\":\"Hello Elixir\"}"}
  end
end
