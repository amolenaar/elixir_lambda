defmodule LambdaRuntimeTest do
  use ExUnit.Case
  doctest LambdaRuntime

  @base_url 'http://lambdahost/2018-06-01'

  def hello_world(_event, _context), do: {:ok, %{:message => "Hello Elixir"}}

  def hello_error(_event, _context), do: {:error, "Error message"}

  test "handling of an event" do
    assert LambdaRuntime.handle_request(HttpcMock, @base_url, &LambdaRuntimeTest.hello_world/2) ==
             {:mock, "{\"message\":\"Hello Elixir\"}"}
  end

  test "an error response" do
    assert LambdaRuntime.handle_request(HttpcMock, @base_url, &LambdaRuntimeTest.hello_error/2) ==
             {:mock, "{\"errorMessage\":\"Error message\",\"errorType\":\"RuntimeException\"}"}
  end

  test "initialization error" do
    System.put_env([{"AWS_LAMBDA_RUNTIME_API", "lambdahost"}, {"_HANDLER", "wrong handler"}])

    assert LambdaRuntime.run(HttpcMock) ==
             {:mock,
              "{\"errorMessage\":\"Invalid handler signature: wrong handler. Expected something like \\\"Module.function\\\".\",\"errorType\":\"InitializationError\"}"}
  end
end

defmodule HttpcMock do
  def request(:get, {'http://lambdahost/2018-06-01/runtime/invocation/next', []}, [], []),
    do:
      {:ok,
       {{'HTTP/1.1', 200, 'OK'},
        [
          {'lambda-runtime-aws-request-id', '--request-id--'}
        ],
        """
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

  def request(
        :post,
        {'http://lambdahost/2018-06-01/runtime/invocation/--request-id--/response', [],
         'application/json', body},
        [],
        []
      ),
      do: {:mock, body}

  def request(
        :post,
        {'http://lambdahost/2018-06-01/runtime/invocation/--request-id--/error', [],
         'application/json', body},
        [],
        []
      ),
      do: {:mock, body}

  def request(
        :post,
        {'http://lambdahost/2018-06-01/runtime/init/error', [], 'application/json', body},
        [],
        []
      ),
      do: {:mock, body}
end
