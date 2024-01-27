package rules

import future.keywords

main := {
    "pass": count(fail) == 0,
    "violations": fail,
}

# only one certificate should be provisioned
fail contains msg if {
    certs := [cert | cert := input.Resources[_]; cert.Type == "AWS::CertificateManager::Certificate"]
    count(certs) != 1

    msg := sprintf("Only one ACM certificate should be provisioned, but found zero or multiple", [])
}

# certificate should be validated using DNS
fail contains msg if {
    certs := [cert | cert := input.Resources[_]; cert.Type == "AWS::CertificateManager::Certificate"]
    validationMethod := certs[_].Properties.ValidationMethod
    validationMethod != "DNS"

    msg := sprintf("ACM certificate should be validated using DNS", [])
}

# certificate should be issued for domain name SUNET.infracourse.cloud
fail contains msg if {
    certs := [cert | cert := input.Resources[_]; cert.Type == "AWS::CertificateManager::Certificate"]
    domain := certs[_].Properties.DomainName
    not endswith(domain, ".infracourse.cloud")

    msg := sprintf("ACM certificate should be issued for domain name SUNET.infracourse.cloud", [])
}

# Certificate subject alternative name should end with .infracourse.cloud
fail contains msg if {
    certs := [cert | cert := input.Resources[_]; cert.Type == "AWS::CertificateManager::Certificate"]

    altNames := certs[_].Properties.SubjectAlternativeNames[_]
    count(altNames) != 1
    not endswith(altNames, ".infracourse.cloud")

    msg := sprintf("Certificate subject alternative name should end with .infracourse.cloud", [])
}

# Certificate subject alternative name should start with *.
fail contains msg if {
    certs := [cert | cert := input.Resources[_]; cert.Type == "AWS::CertificateManager::Certificate"]

    altnames := certs[_].Properties.SubjectAlternativeNames[_]
    count(altnames) != 1
    not startswith(altnames, "*.")

    msg := sprintf("Certificate subject alternative name should start with *.", [])
}