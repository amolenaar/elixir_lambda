# Building an Elixir custom runtime for AWS Lambda

At the most recent AWS Re:invent, Amazon announced support for custom runtimes on AWS Lambda.

AWS has support for quite a few languages out of the box; NodeJS being the fastest, but not always most readable one. Python can be edited from the AWS Console, while for Java, C# and Go binaries have to be uploaded.

The odd thing, in my opinion, is that there are no functional languages in the list of supported languages<sup>[1](#footnote1)</sup>. Although the service name would assume something in the area of [functional programming](https://en.wikipedia.org/wiki/Functional_programming). The working of a function itself is also pretty straightforward: an input events gets processed and an out put event is returned (_emitted_ if you like).

Therefore it seemed a logical step to implement a runtime for a functional programming language. My language of choice is [Elixir](https://elixir-lang.org/), a very readable functional programming language that runs on the BEAM, the Erlang VM.

## Building a runtime

The process of building a runtime is pretty well explained in the [AWS documentation](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-custom.html). In my case I gained a bit of experience by implementing the [bash-based runtime example](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-walkthrough.html).
This gives a good basis for any custom runtime. A runtime will be started by a script called "bootstrap". Already having a Bash-based start script will allows you to test a bit while you set up the runtime.

The runtime itself should be bundled as a zip file. An easy way to build such a zip file -- especially when there are binaries involved -- is with the [lambda-base image](https://hub.docker.com/r/lambci/lambda-base) from the [LambCI project](https://github.com/lambci).

In order to make the zip file not too big, I had to strip it down considerably. The combined layers, including the runtime should be no bigger than 65MB. Many tools, like Observer (monitoring), Mnesia (database), terminal and GUI related code can all be left out. I was able to bring down the size to a decent 23MB.

## Benchmarks

We all want it to be fast. I have not done a full blown performance test, but for the example (hello world) function I deployed the responses were quite okay, in the low tens and many times just a couple of milliseconds.

The cold start speed is about 1.3 seconds, according to AWS X-Ray. This is quite constant. I want to see if I can bring this down.
At this point Erlang's legacy is kind of in the way for its use as a Lambda language: the Erlang/OTP ecosystem is built around applications that never go down, like telephone switches. For Lambda, we have the certainty that this will never be a long lived process.
Cold start times are still compatable with Java, though.

## Final thoughts

The Lambda model is straight forward. It's good to see that the use of custom runtimes does not involve a (serious) performance hit. With the tools described above it's quite straightforward to add support for a language not present on AWS Lambda today. You'll have to do without the web editor, which I did not consider a big loss, since I tend to put my code in git anyway.

Have a look at the [Elixir Lambda](https://github.com/amolenaar/elixir_lambda) repository and give it a go. I've added Cloudformation templates and a Makefile for convenience. Let me know what you think!

<a name="footnote1">[1]</a> Well, you could execute F# code with the .Net runtime.

