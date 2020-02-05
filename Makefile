
LAYER_NAME=elixir-runtime

ERLANG_VERSION=21.2
ELIXIR_VERSION=1.8.0

RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION).zip
EXAMPLE_ZIP=example/example-0.1.0.zip

REV=$(shell git rev-parse --short HEAD)

S3_RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION)-$(REV).zip
S3_EXAMPLE_ZIP=example-$(REV).zip


# Targets:

all: test

build: $(RUNTIME_ZIP) $(EXAMPLE_ZIP)

artifact-bucket: aws-check .cfn-artifact-bucket

elixir-example: aws-check .cfn-elixir-example

test: aws-check elixir-example
	aws lambda invoke --function-name elixir-runtime-example --payload '{"text":"Hello"}' test-output.txt && \
	echo "=== Lambda responded with: ===" && cat test-output.txt && echo && echo "=== end-of-output ==="


.PHONY: all build artifact-bucket elixir-example test aws-check

# Internals:

$(RUNTIME_ZIP): Dockerfile bootstrap
	docker build --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
		--build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
		-t $(LAYER_NAME) . && \
	docker run --rm $(LAYER_NAME) cat /tmp/runtime.zip > ./$(RUNTIME_ZIP)

$(EXAMPLE_ZIP): example/lib/example.ex example/mix.exs $(RUNTIME_ZIP)
	# docker run -w /code -v $(PWD)/example:/code -u $(shell id -u):$(shell id -g) -e MIX_ENV=prod $(LAYER_NAME) mix do test, package
	# don't understand why $(PWD) wasn't resolving to /vagrant/code/elixir_lambda
	docker run -w /code -v /vagrant/code/elixir_lambda/example:/code -u $(shell id -u):$(shell id -g) -e MIX_ENV=prod $(LAYER_NAME) mix do test, package

aws-check:
	@echo "Performing pre-flight check..."
	@aws cloudformation describe-account-limits > /dev/null || { echo "Could not reach AWS, please set your AWS_PROFILE or access keys." >&2 && false; }

.cfn-artifact-bucket: ./templates/artifact-bucket.yaml
	aws cloudformation deploy \
		--stack-name artifact-bucket \
		--template-file ./templates/artifact-bucket.yaml \
		--no-fail-on-empty-changeset && \
	touch .cfn-artifact-bucket

.s3-upload-runtime-$(REV): .cfn-artifact-bucket $(RUNTIME_ZIP)
	ARTIFACT_STORE=$(shell aws cloudformation list-exports |  python -c "import sys, json; print(filter(lambda e: e['Name'] == 'artifact-store', json.load(sys.stdin)['Exports'])[0]['Value'])") && \
	aws s3 cp $(RUNTIME_ZIP) s3://$${ARTIFACT_STORE}/$(S3_RUNTIME_ZIP) && \
	touch .s3-upload-runtime-$(REV)

.s3-upload-example-$(REV): .cfn-artifact-bucket $(EXAMPLE_ZIP)
	ARTIFACT_STORE=$(shell aws cloudformation list-exports |  python -c "import sys, json; print(filter(lambda e: e['Name'] == 'artifact-store', json.load(sys.stdin)['Exports'])[0]['Value'])") && \
	aws s3 cp $(EXAMPLE_ZIP) s3://$${ARTIFACT_STORE}/$(S3_EXAMPLE_ZIP) && \
	touch .s3-upload-example-$(REV)

.cfn-elixir-example: ./templates/elixir-example.yaml .s3-upload-runtime-$(REV) .s3-upload-example-$(REV)
	aws cloudformation deploy \
		--stack-name elixir-example \
		--template-file ./templates/elixir-example.yaml \
		--parameter-overrides \
			"RuntimeZip=$(S3_RUNTIME_ZIP)" \
			"ExampleZip=$(S3_EXAMPLE_ZIP)" \
			"ErlangVersion=$(ERLANG_VERSION)" \
			"ElixirVersion=$(ELIXIR_VERSION)" \
		--capabilities "CAPABILITY_IAM" \
		--no-fail-on-empty-changeset && \
	touch .cfn-elixir-example
