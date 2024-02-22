package rules

import future.keywords

main := {
	"pass": count(fail) == 0,
	"violations": fail,
}

# check that three AWS::SecretsManager::Secret resources are defined
fail contains msg if {
	secrets := [secret | secret := input.Resources[_]; secret.Type == "AWS::SecretsManager::Secret"]
	count(secrets) != 3

	msg := "Three Secrets must be defined (Datadog API key, app secret key, and database credentials)"
}

# check that two container definitions are defined
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	containerDefs := defs[_].Properties.ContainerDefinitions
	count(containerDefs) != 2

	msg := "Exactly two ECS container definitions should be defined"
}

# check that one container definition is the Datadog container
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	ddContainerDef := [cdef | cdef := defs[_].Properties.ContainerDefinitions[_]; cdef.Image == "public.ecr.aws/datadog/agent:latest"]
	count(ddContainerDef) != 1

	msg := "Datadog container must use image public.ecr.aws/datadog/agent:latest"
}

# check that datadog container env vars are defined
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	ddContainerDef := [cdef | cdef := defs[_].Properties.ContainerDefinitions[_]; cdef.Image == "public.ecr.aws/datadog/agent:latest"]
	ddEnv := sort([env | env := ddContainerDef[0].Environment[_].Name])
	ddEnv != ["DD_APM_ENABLED", "DD_APM_NON_LOCAL_TRAFFIC", "DD_PROFILING_ENABLED", "DD_SITE", "ECS_FARGATE", "ECS_FARGATE_METRICS"]

	msg := "Environment variables for Datadog container definition are incorrect"
}

# check that datadog container secrets are defined
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	ddContainerDef := [cdef | cdef := defs[_].Properties.ContainerDefinitions[_]; cdef.Image == "public.ecr.aws/datadog/agent:latest"]
	ddSecret := [secret | secret := ddContainerDef[0].Secrets[_].Name][0]
	ddSecret != "DD_API_KEY"

	msg := "Secrets for Datadog container definition are incorrect"
}

# check Datadog container healthcheck
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	ddContainerDef := [cdef | cdef := defs[_].Properties.ContainerDefinitions[_]; cdef.Image == "public.ecr.aws/datadog/agent:latest"]
	ddHealthCheck := ddContainerDef[0].HealthCheck
	ddHealthCheck.Command != ["CMD-SHELL", "agent health"]

	msg := "Datadog container healthcheck is incorrect"
}

# check Datadog container port mapping
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	ddContainerDef := [cdef | cdef := defs[_].Properties.ContainerDefinitions[_]; cdef.Image == "public.ecr.aws/datadog/agent:latest"]
	ddPortMapping := ddContainerDef[0].PortMappings[0]
	ddPortMapping.ContainerPort != 8126

	msg := "Datadog container port mapping should be port 8126"
}

# check Datadog container port mapping
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	ddContainerDef := [cdef | cdef := defs[_].Properties.ContainerDefinitions[_]; cdef.Image == "public.ecr.aws/datadog/agent:latest"]
	ddPortMapping := ddContainerDef[0].PortMappings[0]
	ddPortMapping.HostPort != 8126

	msg := "Datadog container port mapping (host) should be port 8126"
}

# check Datadog container port mapping
fail contains msg if {
	defs := [def | def := input.Resources[_]; def.Type == "AWS::ECS::TaskDefinition"]
	ddContainerDef := [cdef | cdef := defs[_].Properties.ContainerDefinitions[_]; cdef.Image == "public.ecr.aws/datadog/agent:latest"]
	ddPortMapping := ddContainerDef[0].PortMappings[0]
	ddPortMapping.Protocol != "tcp"

	msg := "Datadog container port mapping should be protocol tcp"
}
