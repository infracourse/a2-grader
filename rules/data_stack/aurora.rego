package rules

import future.keywords

main := {
	"pass": count(fail) == 0,
	"violations": fail,
}

fail contains msg if {
	dbClusters := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	count(dbClusters) != 1

	msg := sprintf("Only one Aurora DB Cluster should be provisioned, but found zero or multiple", [])
}

fail contains msg if {
	subnetGroups := [subnetGroup | subnetGroup := input.Resources[_]; subnetGroup.Type == "AWS::RDS::DBSubnetGroup"]
	subnetIds := subnetGroups[_].Properties.SubnetIds[_]["Fn::ImportValue"]
	cdkLogicalSubnetIds := substring(subnetIds, count(subnetIds) - 16, 8)

	subnets := [{i: subnet} | subnet := input.Resources[i]; endswith(i, cdkLogicalSubnetIds)]
	subnet_types := [tag.Value | tag := subnets[_][_].Properties.Tags[_]; tag.Key == "aws-cdk:subnet-type"][_]
	subnet_types != "Isolated"

	msg := sprintf("Database should be provisioned in isolated subnet, but is instead in %s", [subnet_types])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	engine := dbCluster[_].Properties.Engine
	engine != "aurora-postgresql"

	msg := sprintf("RDS Aurora DB should be of type aurora-postgresql, but instead is %s", [engine])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	engineMode := dbCluster[_].Properties.EngineMode
	engineMode != "serverless"

	msg := sprintf("RDS Aurora DB should be in serverless mode, but instead is %s", [engineMode])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	dbName := dbCluster[_].Properties.DatabaseName
	dbName != "yoctogram"

	msg := sprintf("RDS Aurora DB should be named yoctogram, but instead is %s", [dbName])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	masterUsername := dbCluster[_].Properties.MasterUsername
	masterUsername != "yoctogram"

	msg := sprintf("RDS Aurora DB should have username yoctogram, but instead is %s", [masterUsername])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	masterUserPassword := dbCluster[_].Properties.MasterUserPassword
	not masterUserPassword["Fn::Join"]

	msg := sprintf("RDS Aurora DB should have a generated secret for credentials (1)", [])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	masterUserPassword := dbCluster[_].Properties.MasterUserPassword
	not masterUserPassword["Fn::Join"][1][1].Ref

	msg := sprintf("RDS Aurora DB should have a generated secret for credentials (2)", [])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	masterUserPassword := dbCluster[_].Properties.MasterUserPassword
	not input.Resources[masterUserPassword["Fn::Join"][1].Ref]

	msg := sprintf("RDS Aurora DB should have a generated secret for credentials (3)", [])
}

fail contains msg if {
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	masterUserPassword := dbCluster[_].Properties.MasterUserPassword
	secret := input.Resources[masterUserPassword["Fn::Join"][1][1].Ref]
	not secret.Properties.GenerateSecretString

	msg := sprintf("RDS Aurora DB should have a generated secret for credentials (4)", [])
}

fail contains msg if {
	excludeCharacterSet := "!\"#$%&'()*+,-./:;<=>?@[\\]^`{|}~ "
	dbCluster := [db | db := input.Resources[_]; db.Type == "AWS::RDS::DBCluster"]
	masterUserPassword := dbCluster[_].Properties.MasterUserPassword
	secret := input.Resources[masterUserPassword["Fn::Join"][1][1].Ref]
	secret.Properties.GenerateSecretString.ExcludeCharacters != excludeCharacterSet

	msg := sprintf("RDS Aurora DB generated secret should exclude characters in the given set from the generated password (check assignment spec)", [])
}
