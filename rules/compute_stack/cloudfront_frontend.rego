package rules

import future.keywords

main := {
	"pass": count(fail) == 0,
	"violations": fail,
}

# Secondary behavior for frontend should intercept /api/* requests
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	behavior := distributions[_].Properties.DistributionConfig.CacheBehaviors[_]
	behavior.PathPattern != "/api/*"

	msg := sprintf("Secondary behavior for frontend should intercept /api/* requests", [])
}

# Secondary behavior for frontend should disable caching
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	behavior := distributions[_].Properties.DistributionConfig.CacheBehaviors[_]

	# https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
	behavior.CachePolicyId != "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

	msg := sprintf("Secondary behavior for frontend (/api/*) should disable caching", [])
}

# Primary behavior for frontend should direct to index.html
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	defaultRootObject := distributions[_].Properties.DistributionConfig.DefaultRootObject

	defaultRootObject != "index.html"

	msg := sprintf("Primary behavior for frontend should direct to index.html", [])
}

# Primary behavior for frontend should have 404 redirect to index.html
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	customErrorResponses := distributions[_].Properties.DistributionConfig.CustomErrorResponses

	count(customErrorResponses) != 1

	msg := sprintf("Primary behavior for frontend should have 404 redirect to /index.html (1)", [])
}

# Primary behavior for frontend should have 404 redirect to index.html
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	customErrorResponses := distributions[_].Properties.DistributionConfig.CustomErrorResponses

	customErrorResponses[0].ErrorCode != 404

	msg := sprintf("Primary behavior for frontend should have 404 redirect to /index.html (2)", [])
}

# Primary behavior for frontend should have 404 redirect to index.html
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	customErrorResponses := distributions[_].Properties.DistributionConfig.CustomErrorResponses

	customErrorResponses[0].ResponsePagePath != "/index.html"

	msg := sprintf("Primary behavior for frontend should have 404 redirect to /index.html (3)", [])
}

# Secondary behavior for frontend should direct to api.yoctogram.SUNET.infracourse.cloud
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	domainNames := [domainName | domainName := distributions[_].Properties.DistributionConfig.Origins[_].DomainName; is_string(domainName)]
	domainName := domainNames[_]

	not startswith(domainName, "api.yoctogram")

	msg := sprintf("Primary behavior for frontend should direct to api.yoctogram.SUNET.infracourse.cloud", [])
}

# Origin Access Identity should be used for frontend
fail contains msg if {
	distributions := [dist | dist := input.Resources[_]; dist.Type == "AWS::CloudFront::Distribution"]
	originAccessIdentityRef := [identity | identity := distributions[_].Properties.DistributionConfig.Origins[_].S3OriginConfig.OriginAccessIdentity["Fn::Join"][1][1].Ref]
	count(originAccessIdentityRef) != 3

	msg := sprintf("Cloudfront buckets should have defined origin access identities", [])
}
