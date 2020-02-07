defmodule LambdaRuntime do
  @moduledoc """
  Read Lambda request, process, return, repeat.

  This module provides a simple loop that handles
  Lambda requests.

  Documentation on the Lambda interface can be found at
  https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html.
  """

  @content_type_json 'application/json'
  @lambda_max_timeout_ms 900_000

  def run(httpc \\ :httpc) do
    Application.ensure_all_started(:inets)

    lambda_runtime_api = System.get_env("AWS_LAMBDA_RUNTIME_API")
    handler_name = System.get_env("_HANDLER")
    base_url = "http://#{lambda_runtime_api}/2018-06-01" |> String.to_charlist()

    backend = fn
      :get, url_path, _, _ ->
        httpc.request(:get, {base_url ++ url_path, []}, [], [])

      :post, url_path, content_type, body ->
        httpc.request(:post, {base_url ++ url_path, [], content_type, body}, [], [])
    end

    time_source = fn -> :erlang.system_time(:millisecond) end

    if Regex.match?(~r"^[A-Z:][A-Za-z0-9_.]+$", handler_name) do
      # TODO: check prerequisites. else report to '/runtime/init/error' and quit
      {handler, _} = Code.eval_string("&#{handler_name}/2")

      loop(backend, handler, time_source)
    else
      send_init_error(
        "Invalid handler signature: #{handler_name}. Expected something like \"Module.function\".",
        backend
      )
    end
  end

  def loop(backend, handler, time_source) do
    task = Task.async(fn -> handle(backend, handler, time_source.()) end)
    Task.await(task, @lambda_max_timeout_ms)
    loop(backend, handler, time_source)
  end

  def handle(backend, handler, timestamp) do
    with {:ok, request} <- backend.(:get, '/runtime/invocation/next', nil, nil),
         {:ok, event, context, request_id} <- parse_request(request) do
      task = Task.async(fn -> handler.(event, context) end)
      Task.await(task, context.deadline - timestamp)
      |> send_response(request_id, backend)
    else
      maybe_error ->
        IO.puts("Error while requesting Lambda request: #{inspect(maybe_error)}. So long!")
    end
  end

  defp parse_request({{'HTTP/1.1', 200, 'OK'}, headers, body}) do
    headers = Map.new(headers)
    content_type = Map.get(headers, 'content-type')
    request_id = Map.get(headers, 'lambda-runtime-aws-request-id')

    event =
      case content_type do
        @content_type_json -> Jason.decode!(body)
        _ -> body
      end

    context = %{
      :content_type => content_type,
      :request_id => request_id,
      :deadline => Map.get(headers, 'lambda-runtime-deadline-ms') |> List.to_integer(),
      :function_arn => Map.get(headers, 'lambda-runtime-invoked-function-arn'),
      :trace_id => Map.get(headers, 'lambda-runtime-trace-id'),
      :client_context => Map.get(headers, 'lambda-runtime-client-context'),
      :cognito_identity => Map.get(headers, 'lambda-runtime-cognito-identity')
    }

    {:ok, event, context, request_id}
  end

  defp parse_request(maybe_error), do: {:error, maybe_error}

  defp send_response({:ok, response}, request_id, backend)
       when is_map(response) or is_list(response) do
    {:ok, response} = Jason.encode(response)
    send_response({:ok, @content_type_json, response}, request_id, backend)
  end

  defp send_response({:ok, response}, request_id, backend) when is_binary(response) do
    send_response({:ok, 'text/plain', response}, request_id, backend)
  end

  defp send_response({:ok, response}, request_id, backend),
    do:
      send_response(
        {:ok, 'application/octet-stream', Kernel.inspect(response)},
        request_id,
        backend
      )

  defp send_response({:ok, content_type, response}, request_id, backend)
       when is_binary(content_type) do
    send_response({:ok, content_type |> String.to_charlist(), response}, request_id, backend)
  end

  defp send_response({:ok, content_type, response}, request_id, backend)
       when is_binary(response) do
    url = '/runtime/invocation/' ++ request_id ++ '/response'
    backend.(:post, url, content_type, response)
  end

  defp send_response({:ok, content_type, response}, request_id, backend),
    do: send_response({:ok, content_type, Kernel.inspect(response)}, request_id, backend)

  defp send_response({:error, message}, request_id, backend) when is_binary(message) do
    send_error(message, request_id, backend)
  end

  defp send_response(what_else, request_id, backend),
    do: send_error(Kernel.inspect(what_else), request_id, backend)

  defp send_error(message, request_id, backend) do
    url = '/runtime/invocation/' ++ request_id ++ '/error'

    body =
      Jason.encode!(%{
        "errorMessage" => message,
        "errorType" => "RuntimeException"
      })

    backend.(:post, url, @content_type_json, body)
  end

  defp send_init_error(message, backend) do
    url = '/runtime/init/error'

    body =
      Jason.encode!(%{
        "errorMessage" => message,
        "errorType" => "InitializationError"
      })

    backend.(:post, url, @content_type_json, body)
  end
end
