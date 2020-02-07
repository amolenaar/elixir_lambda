
LAYER_NAME=elixir-runtime

ERLANG_VERSION=22.2
ELIXIR_VERSION=1.10.0

RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION).zip
EXAMPLE_BIN_ZIP=example/example-0.1.0.zip
EXAMPLE_SRC_ZIP=example/example-src.zip

REV=$(shell git rev-parse --short HEAD)

S3_RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION)-$(REV).zip
S3_EXAMPLE_BIN_ZIP=example-bin-$(REV).zip
S3_EXAMPLE_SRC_ZIP=example-src-$(REV).zip


# Targets:

all: test

build: $(RUNTIME_ZIP) $(EXAMPLE_BIN_ZIP) $(EXAMPLE_SRC_ZIP)

clean:
	rm -f .cfn-* .s3-*

artifact-bucket: aws-check .cfn-artifact-bucket

elixir-examples: aws-check .cfn-elixir-example-bin .cfn-elixir-example-src

test: aws-check elixir-examples
	aws lambda invoke --function-name elixir-example-bin --payload '{"text":"Hello"}' test-output.txt && \
	echo "=== Lambda responded with: ===" && cat test-output.txt && echo && echo "=== end-of-output ==="
	aws lambda invoke --function-name elixir-example-src --payload '{"text":"Hello"}' test-output.txt && \
	echo "=== Lambda responded with: ===" && cat test-output.txt && echo && echo "=== end-of-output ==="

clean-aws:
	aws cloudformation delete-stack --stack-name elixir-example-bin && \
	aws cloudformation delete-stack --stack-name elixir-example-src && \
	rm -f .cfn-elixir-example-*

.PHONY: all build artifact-bucket elixir-examples test aws-check

# Internals:

$(RUNTIME_ZIP): Dockerfile bootstrap
	docker build --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
		--build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
		-t $(LAYER_NAME) . && \
	docker run --rm $(LAYER_NAME) cat /tmp/runtime.zip > ./$(RUNTIME_ZIP)

$(EXAMPLE_BIN_ZIP): example/lib/example.ex example/mix.exs $(RUNTIME_ZIP)
	docker run -w /code -v $(PWD)/example:/code -u $(shell id -u):$(shell id -g) -e MIX_ENV=prod $(LAYER_NAME) mix do test, package

$(EXAMPLE_SRC_ZIP): example/lib/example.ex example/mix.exs
	cd example && zip -X $$(basename $(EXAMPLE_SRC_ZIP)) lib/example.ex mix.exs

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

.s3-upload-example-bin-$(REV): .cfn-artifact-bucket $(EXAMPLE_BIN_ZIP)
	ARTIFACT_STORE=$(shell aws cloudformation list-exports |  python -c "import sys, json; print(filter(lambda e: e['Name'] == 'artifact-store', json.load(sys.stdin)['Exports'])[0]['Value'])") && \
	aws s3 cp $(EXAMPLE_BIN_ZIP) s3://$${ARTIFACT_STORE}/$(S3_EXAMPLE_BIN_ZIP) && \
	touch .s3-upload-example-bin-$(REV)

.s3-upload-example-src-$(REV): .cfn-artifact-bucket $(EXAMPLE_SRC_ZIP)
	ARTIFACT_STORE=$(shell aws cloudformation list-exports |  python -c "import sys, json; print(filter(lambda e: e['Name'] == 'artifact-store', json.load(sys.stdin)['Exports'])[0]['Value'])") && \
	aws s3 cp $(EXAMPLE_SRC_ZIP) s3://$${ARTIFACT_STORE}/$(S3_EXAMPLE_SRC_ZIP) && \
	touch .s3-upload-example-src-$(REV)

.cfn-elixir-example-bin: ./templates/elixir-example.yaml .s3-upload-runtime-$(REV) .s3-upload-example-bin-$(REV)
	aws cloudformation deploy \
		--stack-name elixir-example-bin \
		--template-file ./templates/elixir-example.yaml \
		--parameter-overrides \
			"RuntimeZip=$(S3_RUNTIME_ZIP)" \
			"ExampleZip=$(S3_EXAMPLE_BIN_ZIP)" \
			"ErlangVersion=$(ERLANG_VERSION)" \
			"ElixirVersion=$(ELIXIR_VERSION)" \
		--capabilities "CAPABILITY_IAM" \
		--no-fail-on-empty-changeset && \
	touch .cfn-elixir-example-bin

.cfn-elixir-example-src: ./templates/elixir-example.yaml .s3-upload-runtime-$(REV) .s3-upload-example-src-$(REV)
	aws cloudformation deploy \
		--stack-name elixir-example-src \
		--template-file ./templates/elixir-example.yaml \
		--parameter-overrides \
			"RuntimeZip=$(S3_RUNTIME_ZIP)" \
			"ExampleZip=$(S3_EXAMPLE_SRC_ZIP)" \
			"ErlangVersion=$(ERLANG_VERSION)" \
			"ElixirVersion=$(ELIXIR_VERSION)" \
		--capabilities "CAPABILITY_IAM" \
		--no-fail-on-empty-changeset && \
	touch .cfn-elixir-example-src
