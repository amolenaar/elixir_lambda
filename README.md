# Elixir for AWS Lambda

The whole point of AWS Lambda is to provide functions that can be run without the need to manage any servers. Functions are invoked by passing them messages. Uh, that sounds a lot like Erlang/Elixir to me! The clean syntax of Elixir and the functional concepts the language  make it a really good match for use on [AWS Lambda](https://aws.amazon.com/lambda/). Unfortunately the AWS folks haven't put any effort in supporting Elixir, so it looks like we have to do it ourselves.

This project provides a simple way to get started with running Lambda functions written in Elixir. This project contains the runtime layer needed to build your lambda functions.

## Design principes

- Stay close to the current way Lambda functions work: it should be enough to provide one file alone, no full projects
- The approach should be leaner than OTP releases, if possible. We're only trying to execute one function
- Dependencies should be flattened?

- What do I need to support the [Lambda runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html)?

## Some work/considerations

- [ ] How to deal with consolidated bem files (used for protocols) - for now, leave as is.
- [ ] How to keep the lambda code itself as small as possible?
- [ ] Support 5xx and 5xx response codes from AWS Lambda side
- [ ] Mix task for packaging code