
LAYER_NAME=elixir-runtime
REGION=eu-west-1

ERLANG_VERSION=21.2
ELIXIR_VERSION=1.7.4

build: layer-$(ELIXIR_VERSION).zip

publish: .layer-$(ELIXIR_VERSION)-version

layer-$(ELIXIR_VERSION).zip: Dockerfile bootstrap
	docker build --build-arg ERLANG_VERSION=$(ERLANG_VERSION) --build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) -t $(LAYER_NAME) . && \
	docker run --rm $(LAYER_NAME) cat /tmp/otp-$(ERLANG_VERSION).zip > ./layer-$(ELIXIR_VERSION).zip

.layer-$(ELIXIR_VERSION)-version: layer-$(ELIXIR_VERSION).zip
	aws lambda publish-layer-version --region $(REGION) --layer-name $(LAYER_NAME) --zip-file fileb://layer-$(ELIXIR_VERSION).zip \
      --description "Elixir v$(ELIXIR_VERSION) custom runtime" --query Version --output text && touch .layer-$(ELIXIR_VERSION)-version

# TODO: set layer permissions

.PHONY: build publish
