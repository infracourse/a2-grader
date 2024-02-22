package rules

import future.keywords

main := {
	"pass": count(fail) == 0,
	"violations": fail,
}

fail contains msg if {
	clusters := [cluster | cluster := input.Resources[_]; cluster.Type == "AWS::ECS::Cluster"]
	count(clusters) != 1

	msg := sprintf("Exactly one AWS ECS cluster should be defined", [])
}

fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	count(defs) != 1

	msg := sprintf("Exactly one AWS ECS task definition should be defined", [])
}

fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	env := sort([env | env := defs[_].Properties.ContainerDefinitions[_].Environment[_].Name])
	env != ["DEBUG", "FORWARD_FACING_NAME", "PRIVATE_IMAGES_BUCKET", "PRIVATE_IMAGES_CLOUDFRONT_DISTRIBUTION", "PRODUCTION", "PUBLIC_IMAGES_BUCKET", "PUBLIC_IMAGES_CLOUDFRONT_DISTRIBUTION"]

	msg := sprintf("Environment variables for ECS container definition are incorrect", [])
}

fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	containerDef := defs[_].Properties.ContainerDefinitions[_]
	not containerDef.Secrets
	secrets := sort([containerDef | secret := containerDef.Secrets[_].Name])
	secrets != ["POSTGRES_DB", "POSTGRES_HOST", "POSTGRES_PASSWORD", "POSTGRES_PORT", "POSTGRES_USER", "SECRET_KEY"]

	msg := sprintf("Secrets for ECS container definition are incorrect", [])
}

# Check that the ECS task definition has 2048MB of memory
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	defs[_].Properties.ContainerDefinitions[_].Memory != 2048

	msg := sprintf("Fargate task definition should have 2048MB of memory", [])
}

# Check that the ECS task definition has 512 CPU units
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	defs[_].Properties.ContainerDefinitions[_].Cpu != 512

	msg := sprintf("Fargate task definition should have 512 CPU units", [])
}

# Check that the ECS task definition is on Linux
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	defs[_].Properties.ContainerDefinitions[_].RuntimePlatform.OperatingSystemFamily = "LINUX"

	msg := sprintf("Fargate task definition should be on Linux", [])
}

# Check that the ECS task definition is on ARM64
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	defs[_].Properties.ContainerDefinitions[_].RuntimePlatform.RuntimePlatform = "ARM64"

	msg := sprintf("Fargate task definition should be on Linux", [])
}

# Check that there is one port mapping for the Fargate task definition container
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	count(defs[_].Properties.ContainerDefinitions[_].PortMappings) != 1

	msg := sprintf("Fargate task definition should have one port mapping", [])
}

# Check that the protocol for the Fargate task definition container port mapping is tcp
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	defs[_].Properties.ContainerDefinitions[_].PortMappings[_].Protocol != "tcp"

	msg := sprintf("Fargate task definition should have protocol tcp", [])
}

# Check that the app protocol for the Fargate task definition container port mapping is http
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	defs[_].Properties.ContainerDefinitions[_].PortMappings[_].AppProtocol != "http"

	msg := sprintf("Fargate task definition should have app protocol http", [])
}

# Check that the Fargate task definition container port mapping is on port 80
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	defs[_].Properties.ContainerDefinitions[_].PortMappings[_].ContainerPort != 80

	msg := sprintf("Fargate task definition should have container port 80", [])
}
