# CS 40 Assignment 2 Autograder

This repository contains the autograding code and infrastructure setup for CS 40's Assignment 2.

## Architecture

### Synthesizer

`synthesizer` is a Go program designed to be deployed to an AWS Lambda behind AWS API Gateway v2. It runs `cdk synth` on the student CDK code submission and responds with the synthesized Cloudformation JSON.

### Orchestrator

`orchestrator` is a Go program designed to be deployed via a Gradescope Docker container. It processes a student's GitHub repository submission, calls out to `synthesizer`, and runs Open Policy Agent Rego rules on the JSON, outputting test case failures in Gradescope format.

### Cdk

The `cdk` directory contains AWS CDK Go code to deploy `orchestrator` to AWS.

### Rules

The `rules` directory contains Open Policy Agent Rego rules to test the synthesized CloudFormation JSON for deployment properties.

## FAQ

### Why does `cdk synth` need to be done in a separately hosted Lambda?

`cdk synth` executes student code submissions to synthesize CDK to CloudFormation, and student code execution on Gradescope is [a bad idea](https://saligrama.io/blog/post/gradescope-autograder-security).

Moreover, Gradescope doesn't support environment secrets, which hinders our ability to authenticate to AWS. Because VPC synthesis in CDK requires an account feature lookup, not being able to authenticate would cause this step to fail.
