
LAYER_NAME=elixir-runtime
REGION=eu-west-1

ERLANG_VERSION=21.2
ELIXIR_VERSION=1.7.4


build: $(LAYER_NAME)-$(ELIXIR_VERSION).zip

publish: .$(LAYER_NAME)-$(ELIXIR_VERSION)-published

$(LAYER_NAME)-$(ELIXIR_VERSION).zip: Dockerfile bootstrap
	docker build --build-arg ERLANG_VERSION=$(ERLANG_VERSION) \
		--build-arg ELIXIR_VERSION=$(ELIXIR_VERSION) \
		-t $(LAYER_NAME) . &&
	docker run --rm $(LAYER_NAME) cat /tmp/runtime.zip > ./$(LAYER_NAME)-$(ELIXIR_VERSION).zip

.$(LAYER_NAME)-$(ELIXIR_VERSION)-published: $(LAYER_NAME)-$(ELIXIR_VERSION).zip
	aws lambda publish-layer-version --region $(REGION) --layer-name $(LAYER_NAME) --zip-file fileb://$(LAYER_NAME)-$(ELIXIR_VERSION).zip \
      --description "Elixir v$(ELIXIR_VERSION) custom runtime" --query Version --output text && touch .$(LAYER_NAME)-$(ELIXIR_VERSION)-version

# TODO: set layer permissions

.PHONY: build publish
