package rules

import future.keywords

main := {
	"pass": count(fail) == 0,
	"violations": fail,
}

# check that two AWS::Lambda::Function resources are defined
fail contains msg if {
	functions := [fn | fn := input.Resources[_]; fn.Type == "AWS::Lambda::Function"]
	count(functions) != 5

	msg := "Incorrect number of Lambda functions defined (should be 5: your Lambda as well as some other implicit resources)"
}

# check that one of the Lambda functions is deployed from a container image
fail contains msg if {
	functions := [fn | fn := input.Resources[_]; fn.Type == "AWS::Lambda::Function"; fn.Properties.PackageType == "Image"]
	count(functions) != 1

	msg := "Lambda function must be deployed from a container image"
}

# check that Lambda function has 1536MB of memory
fail contains msg if {
	functions := [fn | fn := input.Resources[_]; fn.Type == "AWS::Lambda::Function"; fn.Properties.PackageType == "Image"]
	functions[0].Properties.MemorySize != 1536

	msg := "Lambda function must have 1536 MB of memory"
}

# check that Lambda function is ARM64 architecture
fail contains msg if {
	functions := [fn | fn := input.Resources[_]; fn.Type == "AWS::Lambda::Function"; fn.Properties.PackageType == "Image"]
	functions[0].Properties.Architectures[_] != "arm64"

	msg := "Lambda function must use ARM64 architecture"
}

# check that Lambda function has a 30 second timeout
fail contains msg if {
	functions := [fn | fn := input.Resources[_]; fn.Type == "AWS::Lambda::Function"; fn.Properties.PackageType == "Image"]
	functions[0].Properties.Timeout != 30

	msg := "Lambda function must have a 30 second timeout"
}
