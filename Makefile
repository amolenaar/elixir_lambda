
LAYER_NAME=elixir-runtime

ERLANG_VERSION=21.2
ELIXIR_VERSION=1.7.4

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
	docker run -w /code -v $(PWD)/example:/code -u $(shell id -u):$(shell id -g) -e MIX_ENV=prod $(LAYER_NAME) mix package

artifact-bucket: .artifact-bucket

.artifact-bucket: ./templates/artifact-bucket.yaml
	aws cloudformation deploy \
		--stack-name artifact-bucket \
		--template-file ./templates/artifact-bucket.yaml \
		--no-fail-on-empty-changeset && \
	touch .artifact-bucket

upload-artifacts: .upload-artifacts-$(REV)

.upload-artifacts-$(REV): .artifact-bucket $(RUNTIME_ZIP) $(EXAMPLE_ZIP)
	ARTIFACT_STORE=$(shell aws cloudformation list-exports |  python -c "import sys, json; print(filter(lambda e: e['Name'] == 'artifact-store', json.load(sys.stdin)['Exports'])[0]['Value'])") && \
	aws s3 cp $(RUNTIME_ZIP) s3://$${ARTIFACT_STORE}/$(S3_RUNTIME_ZIP) && \
	aws s3 cp $(EXAMPLE_ZIP) s3://$${ARTIFACT_STORE}/$(S3_EXAMPLE_ZIP) && \
	touch .upload-artifacts-$(REV)

elixir-example: .elixir-example

.elixir-example: ./templates/elixir-example.yaml .upload-artifacts-$(REV)
	aws cloudformation deploy \
		--stack-name elixir-example \
		--template-file ./templates/elixir-example.yaml \
		--parameter-overrides "RuntimeZip=$(S3_RUNTIME_ZIP)" \
							  "ExampleZip=$(S3_EXAMPLE_ZIP)" \
		--capabilities "CAPABILITY_IAM" \
		--no-fail-on-empty-changeset && \
	touch .elixir-example

test: .elixir-example
	aws lambda invoke --function-name elixir-runtime-example --payload '{"text":"Hello"}' test-output.txt && \
	echo "Lambda responded with:" && cat test-output.txt && echo

.PHONY: all build artifact-bucket upload-artifacts elixir-example test
