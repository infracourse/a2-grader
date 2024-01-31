package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/go-git/go-git/v5"
	"github.com/mholt/archiver/v4"
	"github.com/open-policy-agent/opa/rego"
)

const LAMBDA_GATEWAY_URI = "https://grading.management.infracourse.cloud/a2-synth/"

func makeSubmissionZip() ([]byte, error) {
	err := os.Chdir("/autograder/submission")
	if err != nil {
		log.Println(err)
		return nil, err
	}

	// Make directories that would otherwise be Git submodules, but not included by Gradescope submission
	err = os.MkdirAll("web/dist", 0777)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	_, err = git.PlainClone("/autograder/submission/app", false, &git.CloneOptions{
		URL: "https://github.com/infracourse/yoctogram-app.git",
	})
	if err != nil {
		log.Println(err)
		return nil, err
	}

	files, err := archiver.FilesFromDisk(nil, map[string]string{
		".": "",
	})
	if err != nil {
		log.Println(err)
		return nil, err
	}

	buf := &bytes.Buffer{}
	format := archiver.Zip{}
	err = format.Archive(context.TODO(), buf, files)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	return buf.Bytes(), nil
}

type LambdaRequest struct {
	File []byte
}

func getCfnResources(lambdaGatewayURI string, submissionZip []byte) (map[string]interface{}, error) {
	request := LambdaRequest{File: submissionZip}

	buf := &bytes.Buffer{}
	err := json.NewEncoder(buf).Encode(request)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	resp, err := http.Post(lambdaGatewayURI, "application/json", buf)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	defer resp.Body.Close()

	var resources map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&resources)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	return resources, nil
}

func getOpaEvaluator() (func(r *rego.Rego), error) {
	_, err := git.PlainClone("/grader", false, &git.CloneOptions{
		URL: "https://github.com/infracourse/a2-grader.git",
	})
	if err != nil {
		log.Println(err)
		return nil, err
	}

	return rego.LoadBundle("/grader/rules"), nil
}

type GradescopeTest struct {
	Score    float64 `json:"score"`
	MaxScore float64 `json:"max_score"`
	Name     string  `json:"name"`
}

type GradescopeOutput struct {
	Score float64          `json:"score"`
	Tests []GradescopeTest `json:"tests"`
}

func main() {
	submissionZip, err := makeSubmissionZip()
	if err != nil {
		log.Println(err)
		return
	}

	resources, err := getCfnResources(LAMBDA_GATEWAY_URI, submissionZip)
	if err != nil {
		log.Println(err)
		return
	}

	evaluator, err := getOpaEvaluator()
	if err != nil {
		log.Println(err)
		return
	}

	query, err := rego.New(
		evaluator,
		rego.Query("data.rules.main"),
	).PrepareForEval(context.TODO())
	if err != nil {
		log.Println(err)
		return
	}

	results, err := query.Eval(context.TODO(), rego.EvalInput(resources))
	if err != nil || len(results) == 0 {
		log.Println(err)
		return
	}

	failures := results[0].Expressions[0].Value.(map[string]interface{})["violations"].([]interface{})
	gradescopeFormattedOutput := GradescopeOutput{
		Score: 100.0 - (1.33 * float64(len(failures))),
		Tests: make([]GradescopeTest, len(failures)),
	}

	for _, failure := range failures {
		gradescopeFormattedOutput.Tests = append(
			gradescopeFormattedOutput.Tests,
			GradescopeTest{
				Score:    0,
				MaxScore: 1.33,
				Name:     fmt.Sprintf("%v", failure),
			},
		)
	}

	output, err := json.MarshalIndent(gradescopeFormattedOutput, "", "  ")
	if err != nil {
		log.Println(err)
		return
	}

	_ = os.WriteFile("/autograder/results/results.json", output, 0777)
}
