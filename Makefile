
LAYER_NAME=elixir-runtime

ERLANG_VERSION=21.2
ELIXIR_VERSION=1.7.4

RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION).zip
EXAMPLE_ZIP=example.zip

REV=$(shell git rev-parse --short HEAD)

S3_RUNTIME_ZIP=$(LAYER_NAME)-$(ELIXIR_VERSION)-$(REV).zip
S3_EXAMPLE_ZIP=example-$(REV).zip

all: elixir-example

build: $(RUNTIME_ZIP)

upload-artifacts: .upload-artifacts-${REV}

$(RUNTIME_ZIP): Dockerfile bootstrap
	docker build --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
		--build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
		-t $(LAYER_NAME) . &&
	docker run --rm $(LAYER_NAME) cat /tmp/runtime.zip > ./$(RUNTIME_ZIP)

$(EXAMPLE_ZIP): example/lib/example.ex example/mix.exs
	cd example && mix test && MIX_ENV=prod mix compile && \
	(cd _build/prod && zip -r ../../../$(EXAMPLE_ZIP) lib)

artifact-bucket: ./templates/artifact-bucket.yaml
	aws cloudformation deploy \
		--stack-name artifact-bucket \
		--template-file ./templates/artifact-bucket.yaml \
		--no-fail-on-empty-changeset

.upload-artifacts-${REV}: $(RUNTIME_ZIP) $(EXAMPLE_ZIP)
	ARTIFACT_STORE=$(shell aws cloudformation list-exports| jq -r '.Exports[] | select(.Name=="artifact-store") | .Value') && \
	aws s3 cp $(RUNTIME_ZIP) s3://$${ARTIFACT_STORE}/$(S3_RUNTIME_ZIP) && \
	aws s3 cp $(EXAMPLE_ZIP) s3://$${ARTIFACT_STORE}/$(S3_EXAMPLE_ZIP) && \
	touch .upload-artifacts-${REV}

elixir-example: ./templates/elixir-example.yaml upload-artifacts
	aws cloudformation deploy \
		--stack-name elixir-example \
		--template-file ./templates/elixir-example.yaml \
		--parameter-overrides "RuntimeZip=$(S3_RUNTIME_ZIP)" \
							  "ExampleZip=$(S3_EXAMPLE_ZIP)" \
		--capabilities "CAPABILITY_IAM" \
		--no-fail-on-empty-changeset

.PHONY: all build artifact-bucket elixir-example
