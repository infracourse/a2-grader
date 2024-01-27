package rules

import future.keywords

main := {
    "pass": count(fail) == 0,
    "violations": fail,
}

# Only one VPC should be defined
fail contains msg if {
    vpc := [vpc | vpc := input.Resources[_]; vpc.Type == "AWS::EC2::VPC"]
    count(vpc) != 1

    msg := sprintf("Only one VPC is allowed, but found zero or multiple", [])
}

# VPC should have a CIDR block of 10.0.0.0/16
fail contains msg if {
    some vpc
    input.Resources[vpc].Type == "AWS::EC2::VPC"
    input.Resources[vpc].Properties.CidrBlock != "10.0.0.0/16"

    msg := sprintf("EC2 VPC must have a CIDR block of 10.0.0.0/16: %s", [vpc])
}
