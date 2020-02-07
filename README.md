# Elixir for AWS Lambda

The whole point of AWS Lambda is to provide functions that can be run without
the need to manage any servers. Functions are invoked by passing them messages.
Ehm, that sounds a lot like Erlang/Elixir to me! The clean syntax of Elixir and
the functional concepts the language  make it a really good match for use on
[AWS Lambda](https://aws.amazon.com/lambda/). Unfortunately the AWS folks
haven't put any effort in supporting Elixir, so it looks like we have to do it
ourselves.

This project provides a simple way to get started with running Lambda functions
written in Elixir. This project contains the runtime layer needed to build your
lambda functions, an example function, and some Cloudformation templates to get
you started.

## Design principles

- Stay close to the current way Lambda functions work: it should be enough to
  provide one file alone, no full projects.
- The approach should be leaner than OTP releases, if possible. In general,
  we're only trying to execute one function.
- This implementation follows the [Lambda runtime
  API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html).

In order to keep the deployment code as small as possible, many OTP
applications (≈ components) have been left out. The applications bundled with
this layer are reduced to the ones used for networking, including SSL, and
standard library functions. Most notably tooling like Mnesia is left out. It
should have no place of a Lambda function IMHO.

All in all, this keeps the layer relatively small (23MB) for a complete system.


# Getting it up and running

In general, it's good practice to deploy code on AWS by means of Cloudformation
templates. The example setup provided is no different. It does deploy 3 stacks:

 1. An S3 bucket acts as an intermediate storage location for Lambda code
 2. A stack featuring the Elixir runtime, with an example function containing
    compiled code (BEAM files).
 3. A stack containing Elixir source code. This project can be edited with the
    AWS Lambda editor.

To work with this repo, there are a few prerequisites to set up:

 1. [docker](https://www.docker.com), used to build the custom runtime and example
 2. [aws-cli](https://aws.amazon.com/cli/), installed using Python 2 or 3
 3. make ([GNU Make](https://www.gnu.org/software/make/))

To get started, make sure you can access your AWS account (e.g. try `aws
cloudformation list-stacks`). If this does not work, set your `AWS_PROFILE` or
access keys. You do not need to have Erlang/Elixir installed on your system since
we do the building from Docker containers.

To deploy the S3 bucket stack and the example stacks, simply type:

    make

This will build the zip files, upload them to S3 and deploy the custom runtime
and Lambda functions.

To test the function, simply call:

    make test

## Building a Lambda function

A Lambda function can be any function defined by `ModuleName.function_name`. The
function should take two arguments, `event` and `context`.

A simple Lambda handler module could look like this:

    defmodule Example do

      def hello(_event, _context) do
        {:ok, %{ :message => "Elixir on AWS Lambda" }}
      end

    end

The event is a map with event information. The contents depend on the type of event
received (API Gateway, SQS, etc.).

The response can be in one of the following forms:

    {:ok, content}
    {:ok, content_type, content}
    {:error, message}

Content can be a map or list, in which case it's serialized to JSON. If its a binary (string)
it will be returned as `text/plain` by default. Any other type will be "inspected" returned
as `application/octet-stream` by default.

If a `content_type` is provided that is used instead. Binary content is returned as is, the
rest is "inspected".

The context map contains some extra info about the event, as charlists(!):

    %{
      :content_type => 'application/json'
      :request_id => 'abcdef-1234-1234`
      :deadline => 1547815888328
      :function_arn => 'arn:aws:lambda:eu-west-1:1234567890:function:elixir-runtime-example'
      :trace_id => 'Root=1-5c4...'
      :client_context => 'a6f...'
      :cognito_identity => '6d8...'
    }

The runtime is bundled with [Jason](https://hex.pm/packages/jason), a fast 100% Elixir JSON
serializer/deserializer.
