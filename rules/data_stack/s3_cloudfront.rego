package rules

import future.keywords

main := {
    "pass": count(fail) == 0,
    "violations": fail,
}

# TODO adjust for frontend
fail contains msg if {
    distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
    count(distributions) != 2

    msg := sprintf("Two CloudFront distributions should be provisioned, but only got one", [])
}

fail contains msg if {
    distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
    origins := distributions[_].Properties.DistributionConfig.Origins
    bucketRef := origins[_].DomainName["Fn::GetAtt"][0]
    not input.Resources[bucketRef]

    msg := sprintf("CloudFront distributions should be backed by S3 buckets (1)", [])
}

fail contains msg if {
    distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
    origins := distributions[_].Properties.DistributionConfig.Origins
    bucketRef := origins[_].DomainName["Fn::GetAtt"][0]
    input.Resources[bucketRef].Type != "AWS::S3::Bucket"

    msg := sprintf("CloudFront distributions should be backed by S3 buckets (2)", [])
}

fail contains msg if {
    buckets := [bucket | bucket := input.Resources[_]; bucket.Type == "AWS::S3::Bucket"]
    configs := buckets[_].Properties.PublicAccessBlockConfiguration
    not checkBucketRestricted(configs)

    msg := sprintf("S3 buckets should block public ACLs, policies, ignore public ACLs, and restrict public buckets", [])
}

checkBucketRestricted(config) {
    config.BlockPublicAcls
    config.BlockPublicPolicy
    config.IgnorePublicAcls
    config.RestrictPublicBuckets
}