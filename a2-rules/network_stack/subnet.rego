package rules

import future.keywords

main := {
    "pass": count(fail) == 0,
    "violations": fail,
}

fail contains msg if {
    subnets := [subnet | subnet := input.Resources[_]; subnet.Type == "AWS::EC2::Subnet"]
    azs := {az | az := subnets[_].Properties.AvailabilityZone}
    azs != {"us-west-2a", "us-west-2b"}

    msg := sprintf("VPC subnets must be in us-west-2a and us-west-2b availability zones, but found %s", [azs])
}

fail contains msg if {
    not two_subnets_each_type
    msg := sprintf("Must have an isolated, private, and public subnet per availability zone", [])
}

fail contains msg if {
    subnets := [subnet | subnet := input.Resources[_]; subnet.Type == "AWS::EC2::Subnet"]
    cidr_blocks := subnets[_].Properties.CidrBlock
    not endswith(cidr_blocks, "/24")

    msg := sprintf("Each subnet must be a CIDR /24", [])
}

two_subnets_each_type {
    num_subnets_of_type("Isolated", 2)
    num_subnets_of_type("Private", 2)
    num_subnets_of_type("Public", 2)
}

num_subnets_of_type(type, num) {
    subnets := [subnet | subnet := input.Resources[_]; subnet.Type == "AWS::EC2::Subnet"]
    subnet_types := [tag | tag := subnets[_].Properties.Tags[_]; tag.Key == "aws-cdk:subnet-type"]
    count([subnet_type | subnet_type := subnet_types[_].Value; subnet_type == type]) == num
}