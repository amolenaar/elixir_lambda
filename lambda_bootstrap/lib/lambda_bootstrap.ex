defmodule LambdaBootstrap do
  @moduledoc """
  Read Lambda request, process, return, repeat.

  This module provides a simple loop that handles
  Lambda requests.
  """

  @content_type_json 'application/json'

  def bootstrap do
    Application.ensure_all_started(:inets)

    lambda_runtime_api = System.get_env("AWS_LAMBDA_RUNTIME_API")
    handler = System.get_env("_HANDLER")
    base_url = "http://#{lambda_runtime_api}/2018-06-01" |> String.to_charlist

    # TODO: check prerequisites. else report to '/runtime/init/error' and quit
    Code.compile_string("defmodule LambdaRuntime.Handler, do: (def h(e, c), do: " <> handler <> "(e, c))")

    loop(:httpc, base_url, &LambdaRuntime.Handler.h/2)
  end

  def loop(httpc, base_url, handler) do
    handle_request(httpc,base_url, handler)
    loop(httpc, base_url, handler)
  end

  def handle_request(httpc, base_url, handler) do
    case httpc.request(:get, {base_url ++ '/runtime/invocation/next', []}, [], []) do
      {:ok, {{'HTTP/1.1', 200, 'OK'}, headers, body}} ->
        headers = Map.new(headers) |> IO.inspect
        content_type = Map.get(headers, 'content-type')
        request_id = Map.get(headers, 'lambda-runtime-aws-request-id')
        event = case content_type do
          @content_type_json -> Jason.decode!(body)
          _ -> body
        end
        context = %{
          :content_type => content_type,
          :request_id => request_id,
          :deadline => Map.get(headers, 'lambda-runtime-deadline-ms'),
          :function_arn => Map.get(headers, 'lambda-runtime-invoked-function-arn'),
          :trace_id => Map.get(headers, 'lambda-runtime-trace-id'),
          :client_context => Map.get(headers, 'lambda-runtime-client-context'),
          :cognito_identity => Map.get(headers, 'lambda-runtime-cognito-identity')
        }

        case handler.(event, context) do
          {:ok, response} when is_map(response) or is_list(response) or is_tuple(response) ->
            {:ok, response} = Jason.encode(response)
            send_response(httpc, base_url, request_id, @content_type_json, response)
          {:ok, response} when is_binary(response) ->
            send_response(httpc, base_url, request_id, 'text/plain', response)
          {:ok, response} ->
            send_response(httpc, base_url, request_id, 'application/octet-stream', Kernel.inspect(response))
          {:ok, content_type, response} when is_binary(response) ->
            send_response(httpc, base_url, request_id, content_type, response)
          {:ok, content_type, response} ->
            send_response(httpc, base_url, request_id, content_type, Kernel.inspect(response))
          {:error, message} ->
            send_error(httpc, base_url, request_id, message)
          what_else ->
            send_error(httpc, base_url, request_id, Kernel.inspect(what_else))
        end

      maybe_error ->
        IO.puts("Error while requesting Lambda request: #{inspect maybe_error}. So long!")
    end
  end

  def send_response(httpc, base_url, request_id, content_type, response) do
    url = base_url ++ '/runtime/invocation/' ++ request_id ++ '/response'
    httpc.request(:post, {url, [], content_type, response}, [], [])
  end

  def send_error(httpc, base_url, request_id, message) do
    url = base_url ++ '/runtime/invocation/' ++ request_id ++ '/error'
    httpc.request(:post, {url, [], @content_type_json, Jason.encode!(%{
      "errorMessage" => message,
      "errorType" => "InvalidEventDataException"
    })}, [], [])
  end

end
