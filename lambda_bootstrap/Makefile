
package:
	mix compile
	(cd _build/dev && zip -ur ../../function.zip lib)

create:
	aws lambda create-function --profile arjanmolenaar --function-name elixir-test \
		--zip-file fileb://function.zip --handler Hello.world --runtime provided \
		--role arn:aws:iam::$(ACCOUNT_ID):role/service-role/lambda-role && \
	aws lambda update-function-configuration --function-name elixir-test \
		--layers arn:aws:lambda:eu-west-1:$(ACCOUNT_ID):layer:elixir-runtime:1

update: package
	aws lambda update-function-code --function-name elixir-test --zip-file fileb://function.zip

invoke:
	aws lambda invoke --function-name elixir-test --payload '{"text":"Hello"}' response.txt && \
	cat response.txt

.PHONY: package create update invoke