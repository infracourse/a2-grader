package rules

import future.keywords

main := {
	"pass": count(fail) == 0,
	"violations": fail,
}

fail contains msg if {
	roles := [role | role := input.Resources[_]; role.Type == "AWS::IAM::Role"; role.Properties.AssumeRolePolicyDocument.Statement[0].Action == "sts:AssumeRoleWithWebIdentity"]
	count(roles) != 1

	msg := "Role under with action sts:AssumeRoleWithWebIdentity not found"
}

# Role can only be assumed by specific conditions
fail contains msg if {
	roles := [role | role := input.Resources[_]; role.Type == "AWS::IAM::Role"; role.Properties.AssumeRolePolicyDocument.Statement[0].Action == "sts:AssumeRoleWithWebIdentity"]

	conditions := [cond | cond := roles[_].Properties.AssumeRolePolicyDocument.Statement[_].Condition.StringEquals]

	pattern := "^repo:[A-Za-z0-9-]*/[A-Za-z0-9-]*:ref:refs/heads/main$"

	not re_match(pattern, conditions[0]["token.actions.githubusercontent.com:sub"])

	msg := "Role principal is improperly configured"
}

# Role can only be assumed by specific conditions
fail contains msg if {
	roles := [role | role := input.Resources[_]; role.Type == "AWS::IAM::Role"; role.Properties.AssumeRolePolicyDocument.Statement[0].Action == "sts:AssumeRoleWithWebIdentity"]

	conditions := [cond | cond := roles[_].Properties.AssumeRolePolicyDocument.Statement[_].Condition.StringEquals]

	pattern := "^repo:[A-Za-z0-9-]*/[A-Za-z0-9-]*:ref:refs/heads/main$"

	conditions[0]["token.actions.githubusercontent.com:aud"] != "sts.amazonaws.com"

	msg := "Role principal is improperly configured"
}

# Max session duration should be 3600
fail contains msg if {
	roles := [role | role := input.Resources[_]; role.Type == "AWS::IAM::Role"; role.Properties.AssumeRolePolicyDocument.Statement[0].Action == "sts:AssumeRoleWithWebIdentity"]
	session_duration := roles[_].Properties.MaxSessionDuration
	session_duration != 3600
	msg := "Max session duration should be one hour"
}

# Role should ONLY have access to AmazonEC2ContainerRegistryFullAccess and AmazonECS_FullAccess
fail contains msg if {
	roles := [role | role := input.Resources[_]; role.Type == "AWS::IAM::Role"; role.Properties.AssumeRolePolicyDocument.Statement[_].Action == "sts:AssumeRoleWithWebIdentity"]
	managedPolicyArnSuffixes := sort([suffix | suffix := roles[_].Properties.ManagedPolicyArns[_]["Fn::Join"][1][2]])
	managedPolicyArnSuffixes != [":iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", ":iam::aws:policy/AmazonECS_FullAccess"]

	msg := sprintf("Role should ONLY have access to AmazonEC2ContainerRegistryFullAccess and AmazonECS_FullAccess", [])
}
