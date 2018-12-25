# Elixir for AWS Lambda

The whole point of AWS Lambda is to provide functions that can be run without the need to manage any servers. Functions are invoked by passing them messages. Uh, that sounds a lot like Erlang/Elixir to me! The clean syntax of Elixir and the functional concepts the language  make it a really good match for use on [AWS Lambda](https://aws.amazon.com/lambda/). Unfortunately the AWS folks haven't put any effort in supporting Elixir, so it looks like we have to do it ourselves.

This project provides a simple way to get started with running Lambda functions written in Elixir. This project contains the runtime layer needed to build your lambda functions.

## Design principes

- Stay close to the current way Lambda functions work: it should be enough to provide one file alone, no full projects.
- The approach should be leaner than OTP releases, if possible. In general, we're only trying to execute one function.
- This implementation follows the [Lambda runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html).

In order to keep the deployment code as small as possible, many OTP applications have been left out.
The applications included in the runtime are:

 * asn1-5.0.8
 * common_test-1.16.1
 * compiler-7.3
 * crypto-4.4
 * erl_interface-3.10.4
 * erts-10.2
 * et-1.6.4
 * eunit-2.3.7
 * ftp-1.0.1
 * hipe-3.18.2
 * inets-7.0.3
 * kernel-6.2
 * megaco-3.18.4
 * os_mon-2.4.7
 * parsetools-2.1.8
 * public_key-1.6.4
 * runtime_tools-1.13.1
 * sasl-3.3
 * ssh-4.7.2
 * ssl-9.1
 * stdlib-3.7
 * syntax_tools-2.1.6
 * tools-3.0.2

There may be a few more than can be left out, though. Most notably tooling like Mnesia is left out. It should have no place of a Lambda function IMHO.

Al in all this keeps the layer relatively small (41MB) for a complete system.


# Getting it up and running

In general, it's good practice to deploy code on AWS by meand of Cloudformation templates. The example setup provided is
no different. It does deploy 2 stacks:

 1. An S3 bucket acts as an intermediate store to put stuff in Lambda
 2. A stack featuring the Elixir runtime, with an example function.

To work with this repo, there are a few prerequisites to set up:

 1. [docker](https://www.docker.com), used to build the custom runtime and example
 2. [aws-cli](https://aws.amazon.com/cli/), installed using Python 2 or 3
 3. make ([GNU Make](https://www.gnu.org/software/make/))
 4. [jq](https://stedolan.github.io/jq/), the JSON query tool

To get started, make sure you can access your AWS account (e.g. try `aws cloudformation list-stacks`). If this does not
work, set your `AWS_DEFAULT_PROFILE` or access keys.

To deploy the S3 bucket stack and the example stack, simply type:

    make

This will build the zip files, upload them to S3 and deploy the custom runtime and a Lambda function.


## Some work/considerations

- [X] How to deal with consolidated bem files (used for protocols) - for now, leave as is.
- [X] How to keep the lambda code itself as small as possible? Removed as many apps from the deployment as possible
- [ ] Support 5xx and 5xx response codes from AWS Lambda side
- [ ] Mix task for packaging code

