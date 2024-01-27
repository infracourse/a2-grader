package main

import (
	"encoding/json"
	"os"
	"path"

	"github.com/aws/aws-cdk-go/awscdk/v2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsapigatewayv2"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsapigatewayv2integrations"
	"github.com/aws/aws-cdk-go/awscdk/v2/awscertificatemanager"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsiam"
	"github.com/aws/aws-cdk-go/awscdk/v2/awslambda"
	"github.com/aws/aws-cdk-go/awscdk/v2/awslogs"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsroute53"
	"github.com/aws/aws-cdk-go/awscdk/v2/awsroute53targets"
	"github.com/aws/constructs-go/constructs/v10"
	"github.com/aws/jsii-runtime-go"
)

type CdkStackProps struct {
	awscdk.StackProps
}

const ZONE_NAME = "management.infracourse.cloud"
const DOMAIN_NAME = "grading." + ZONE_NAME

func DnsStack(scope constructs.Construct, id string, props *CdkStackProps) (awscdk.Stack, awsroute53.IHostedZone) {
	var sprops awscdk.StackProps

	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	zone := awsroute53.NewHostedZone(stack, jsii.String("CdkHostedZone"), &awsroute53.HostedZoneProps{
		ZoneName: jsii.String(ZONE_NAME),
	})

	return stack, zone
}

func GradingLambdaStack(scope constructs.Construct, id string, zone awsroute53.IHostedZone, props *CdkStackProps) awscdk.Stack {
	var sprops awscdk.StackProps

	if props != nil {
		sprops = props.StackProps
	}
	stack := awscdk.NewStack(scope, &id, &sprops)

	lambda := awslambda.NewDockerImageFunction(stack, jsii.String("GradingLambda"), &awslambda.DockerImageFunctionProps{
		Code: awslambda.DockerImageCode_FromImageAsset(
			jsii.String(path.Join(".", "../synthesizer")),
			&awslambda.AssetImageCodeProps{},
		),
		Architecture: awslambda.Architecture_ARM_64(),
		Tracing:      awslambda.Tracing_ACTIVE,
		Timeout:      awscdk.Duration_Minutes(jsii.Number(5)),
		MemorySize:   jsii.Number(2048),
	})

	lambda.Role().AddManagedPolicy(
		awsiam.ManagedPolicy_FromManagedPolicyArn(
			stack,
			jsii.String("GradingLambdaPolicy"),
			jsii.String("arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"),
		),
	)

	cert := awscertificatemanager.NewCertificate(stack, jsii.String("GradingCertificate"), &awscertificatemanager.CertificateProps{
		DomainName: jsii.String("*." + ZONE_NAME),
		Validation: awscertificatemanager.CertificateValidation_FromDns(zone),
	})

	dn := awsapigatewayv2.NewDomainName(stack, jsii.String("GradingDomainName"), &awsapigatewayv2.DomainNameProps{
		DomainName:  jsii.String(DOMAIN_NAME),
		Certificate: cert,
	})

	api := awsapigatewayv2.NewHttpApi(stack, jsii.String("GradingApi"), &awsapigatewayv2.HttpApiProps{
		DefaultIntegration: awsapigatewayv2integrations.NewHttpLambdaIntegration(
			jsii.String("GradingLambdaIntegration"),
			lambda,
			&awsapigatewayv2integrations.HttpLambdaIntegrationProps{},
		),
		DefaultDomainMapping: &awsapigatewayv2.DomainMappingOptions{
			DomainName: dn,
			MappingKey: jsii.String("a2-synth"),
		},
	})

	logFormat, err := json.Marshal(map[string]interface{}{
		"requestId":        "$context.requestId",
		"userAgent":        "$context.identity.userAgent",
		"sourceIp":         "$context.identity.sourceIp",
		"requestTime":      "$context.requestTime",
		"requestTimeEpoch": "$context.requestTimeEpoch",
		"httpMethod":       "$context.httpMethod",
		"path":             "$context.path",
		"status":           "$context.status",
		"protocol":         "$context.protocol",
		"responseLength":   "$context.responseLength",
		"domainName":       "$context.domainName",
	})
	if err != nil {
		panic(err)
	}

	accessLogs := awslogs.NewLogGroup(stack, jsii.String("GradingAccessLogs"), &awslogs.LogGroupProps{})

	stage := api.DefaultStage().Node().DefaultChild().(awsapigatewayv2.CfnStage)
	stage.SetAccessLogSettings(&awsapigatewayv2.CfnStage_AccessLogSettingsProperty{
		DestinationArn: accessLogs.LogGroupArn(),
		Format:         jsii.String(string(logFormat)),
	})

	awsroute53.NewARecord(stack, jsii.String("GradingAliasRecord"), &awsroute53.ARecordProps{
		Zone:       zone,
		RecordName: jsii.String("grading"),
		Target: awsroute53.RecordTarget_FromAlias(
			awsroute53targets.NewApiGatewayv2DomainProperties(
				dn.RegionalDomainName(),
				dn.RegionalHostedZoneId(),
			),
		),
	})

	return stack
}

func main() {
	defer jsii.Close()

	app := awscdk.NewApp(nil)

	_, zone := DnsStack(app, "DnsStack", &CdkStackProps{
		awscdk.StackProps{
			Env: env(),
		},
	})

	GradingLambdaStack(app, "GradingLambdaStack", zone, &CdkStackProps{
		awscdk.StackProps{
			Env: env(),
		},
	})

	app.Synth(nil)
}

func env() *awscdk.Environment {
	return &awscdk.Environment{
		Account: jsii.String(os.Getenv("CDK_DEFAULT_ACCOUNT")),
		Region:  jsii.String(os.Getenv("CDK_DEFAULT_REGION")),
	}
}
