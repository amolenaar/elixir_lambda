defmodule LambdaRuntimeTest do
  use ExUnit.Case
  doctest LambdaRuntime

  defp handle(handler),
    do: LambdaRuntime.handle(&BackendMock.backend/4, handler)

  test "handling of an event with a dictionary" do
    assert handle(fn _e, _c -> {:ok, %{:message => "Hello Elixir"}} end) ==
             {:mock, 'application/json', "{\"message\":\"Hello Elixir\"}"}
  end

  test "handling of an event with a list" do
    assert handle(fn _e, _c -> {:ok, [1, 2, 3]} end) == {:mock, 'application/json', "[1,2,3]"}
  end

  test "handling of an event with a charlist" do
    assert handle(fn _e, _c -> {:ok, 'abc'} end) == {:mock, 'application/json', "[97,98,99]"}
  end

  test "handling of an event with a binary" do
    assert handle(fn _e, _c -> {:ok, "Hello Elixir"} end) == {:mock, 'text/plain', "Hello Elixir"}
  end

  test "handling of an event with a tuple" do
    assert handle(fn _e, _c -> {:ok, {1, 2, 3}} end) ==
             {:mock, 'application/octet-stream', "{1, 2, 3}"}
  end

  test "handling of an event with a number" do
    assert handle(fn _e, _c -> {:ok, 42} end) == {:mock, 'application/octet-stream', "42"}
  end

  test "handling of an event with custom content type" do
    assert handle(fn _e, _c -> {:ok, 'text/numeral', 42} end) == {:mock, 'text/numeral', "42"}
  end

  test "handling of an event with custom content type defined with a string" do
    assert handle(fn _e, _c -> {:ok, "text/numeral", 42} end) == {:mock, 'text/numeral', "42"}
  end

  test "an error response" do
    assert handle(fn _e, _c -> {:error, "Error message"} end) ==
             {:mock, 'application/json',
              "{\"errorMessage\":\"Error message\",\"errorType\":\"RuntimeException\"}"}
  end

  test "an non-string error response" do
    assert handle(fn _e, _c -> {:error, %{:message => "Error message"}} end) ==
             {:mock, 'application/json',
              "{\"errorMessage\":\"{:error, %{message: \\\"Error message\\\"}}\",\"errorType\":\"RuntimeException\"}"}
  end

  test "handling of an event with just some output" do
    assert handle(fn _e, _c -> {:meaning, 42} end) ==
             {:mock, 'application/json',
              "{\"errorMessage\":\"{:meaning, 42}\",\"errorType\":\"RuntimeException\"}"}
  end

  test "initialization error" do
    System.put_env([{"AWS_LAMBDA_RUNTIME_API", "lambdahost"}, {"_HANDLER", "wrong handler"}])

    assert LambdaRuntime.run(HttpcMock) ==
             {:mock, 'application/json',
              "{\"errorMessage\":\"Invalid handler signature: wrong handler. Expected something like \\\"Module.function\\\".\",\"errorType\":\"InitializationError\"}"}
  end
end

defmodule BackendMock do
  def backend(:get, '/runtime/invocation/next', _, _),
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

  def backend(
        :post,
        '/runtime/invocation/--request-id--/response',
        content_type,
        body
      ),
      do: {:mock, content_type, body}

  def backend(
        :post,
        '/runtime/invocation/--request-id--/error',
        content_type,
        body
      ),
      do: {:mock, content_type, body}
end

defmodule HttpcMock do
  def request(
        :post,
        {'http://lambdahost/2018-06-01/runtime/init/error', [], content_type, body},
        [],
        []
      ),
      do: {:mock, content_type, body}
end
