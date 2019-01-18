
LAYER_NAME=elixir-runtime

ERLANG_VERSION=21.2
ELIXIR_VERSION=1.8.0

RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION).zip
EXAMPLE_ZIP=example/example-0.1.0.zip

REV=$(shell git rev-parse --short HEAD)

S3_RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION)-$(REV).zip
S3_EXAMPLE_ZIP=example-$(REV).zip

all: elixir-example

build: $(RUNTIME_ZIP)

$(RUNTIME_ZIP): Dockerfile bootstrap
	docker build --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
		--build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
		-t $(LAYER_NAME) . && \
	docker run --rm $(LAYER_NAME) cat /tmp/runtime.zip > ./$(RUNTIME_ZIP)

example: $(EXAMPLE_ZIP)

$(EXAMPLE_ZIP): example/lib/example.ex example/mix.exs $(RUNTIME_ZIP)
	docker run -w /code -v $(PWD)/example:/code -u $(shell id -u):$(shell id -g) -e MIX_ENV=prod $(LAYER_NAME) mix do test, package

aws-check:
	@echo "Performing a pre-flight check..."
	aws cloudformation describe-account-limits > /dev/null || { echo "Could not reach AWS, please set your AWS_PROFILE or access keys." >&2 && false; }

artifact-bucket: .cfn-artifact-bucket

.cfn-artifact-bucket: aws-check ./templates/artifact-bucket.yaml
	aws cloudformation deploy \
		--stack-name artifact-bucket \
		--template-file ./templates/artifact-bucket.yaml \
		--no-fail-on-empty-changeset && \
	touch .cfn-artifact-bucket

upload-artifacts: .s3-upload-artifacts-$(REV)

.s3-upload-artifacts-$(REV): aws-check .cfn-artifact-bucket $(RUNTIME_ZIP) $(EXAMPLE_ZIP)
	ARTIFACT_STORE=$(shell aws cloudformation list-exports |  python -c "import sys, json; print(filter(lambda e: e['Name'] == 'artifact-store', json.load(sys.stdin)['Exports'])[0]['Value'])") && \
	aws s3 cp $(RUNTIME_ZIP) s3://$${ARTIFACT_STORE}/$(S3_RUNTIME_ZIP) && \
	aws s3 cp $(EXAMPLE_ZIP) s3://$${ARTIFACT_STORE}/$(S3_EXAMPLE_ZIP) && \
	touch .s3-upload-artifacts-$(REV)

elixir-example: .cfn-elixir-example

.cfn-elixir-example: aws-check ./templates/elixir-example.yaml .s3-upload-artifacts-$(REV)
	aws cloudformation deploy \
		--stack-name elixir-example \
		--template-file ./templates/elixir-example.yaml \
		--parameter-overrides "RuntimeZip=$(S3_RUNTIME_ZIP)" \
							  "ExampleZip=$(S3_EXAMPLE_ZIP)" \
							  "ErlangVersion=$(ERLANG_VERSION)" \
							  "ElixirVersion=$(ELIXIR_VERSION)" \
		--capabilities "CAPABILITY_IAM" \
		--no-fail-on-empty-changeset && \
	touch .cfn-elixir-example

test: aws-check .cfn-elixir-example
	aws lambda invoke --function-name elixir-runtime-example --payload '{"text":"Hello"}' test-output.txt && \
	echo "=== Lambda responded with: ===" && cat test-output.txt && echo && echo "=== end-of-output ==="

.PHONY: all build aws-check artifact-bucket upload-artifacts elixir-example test
