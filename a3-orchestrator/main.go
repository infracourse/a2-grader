package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"

	"github.com/go-git/go-git/v5"
	"github.com/mholt/archiver/v4"
	"github.com/open-policy-agent/opa/rego"
)

const LAMBDA_GATEWAY_URI = "https://5tvpsbxptgyc6m7ffmgmxvdw7m0pbmkb.lambda-url.us-east-1.on.aws/"
const GRADER_TOKEN = "INSECURE-CHANGE-BEFORE-RELEASE"

func getSunet() (string, error) {
	contents, err := os.ReadFile("/autograder/submission/SUNET")
	if err != nil {
		log.Println(err)
		return "", err
	}

	return strings.TrimSpace(string(contents)), nil
}

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

type GradingLambdaRequest struct {
	File []byte
}

func getCfnResources(gradingLambdaURI string, submissionZip []byte) (map[string]interface{}, error) {
	request := GradingLambdaRequest{File: submissionZip}

	buf := &bytes.Buffer{}
	err := json.NewEncoder(buf).Encode(request)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	resp, err := http.Post(gradingLambdaURI, "application/json", buf)
	if err != nil {
		log.Println(err)
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		log.Println("HTTP status code", resp.StatusCode)
		return nil, fmt.Errorf("synthesizer lambda returned HTTP status code %d", resp.StatusCode)
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
		URL: "https://github.com/infracourse/iac-grader.git",
	})
	if err != nil {
		log.Println(err)
		return nil, err
	}

	return rego.LoadBundle("/grader/a3-rules"), nil
}

type GradescopeTest struct {
	Score    float64 `json:"score"`
	MaxScore float64 `json:"max_score"`
	Name     string  `json:"name"`
	Output   string  `json:"output"`
}

type RuntimeCheckOutput struct {
	RuntimeGrade int              `json:"runtime_grade"`
	Results      []GradescopeTest `json:"results"`
}

func doRuntimeCheck() (RuntimeCheckOutput, error) {
	cmd := exec.Command("python3", "/autograder/runtime/grade.py")
	if cmd.Err != nil {
		log.Println(cmd.Err)
		return RuntimeCheckOutput{}, cmd.Err
	}

	var stdout bytes.Buffer
	cmd.Stdout = &stdout

	if err := cmd.Run(); err != nil {
		log.Println(err)
		return RuntimeCheckOutput{}, err
	}

	var results RuntimeCheckOutput
	err := json.Unmarshal(stdout.Bytes(), &results)
	if err != nil {
		log.Println(err)
		return results, err
	}

	return results, nil
}

func getSubmittedFlag() (string, error) {
	contents, err := os.ReadFile("/autograder/submission/FLAG")
	if err != nil {
		log.Println(err)
		return "", err
	}

	return string(contents), nil
}

type ValidateResponse struct {
	Correct bool `json:"correct"`
}

func validateFlag() (bool, error) {
	submittedFlag, err := getSubmittedFlag()
	if err != nil {
		log.Println(err)
		return false, err
	}

	sunet, err := getSunet()
	if err != nil {
		log.Println(err)
		return false, err
	}

	req, err := http.NewRequest(
		"GET",
		fmt.Sprintf("https://provisiondns.infracourse.cloud/a3/grader/%s?flag=%s", sunet, submittedFlag),
		nil,
	)
	if err != nil {
		log.Println(err)
		return false, err
	}

	req.Header.Set("X-Grader-Token", GRADER_TOKEN)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Println(err)
		return false, err
	}

	if resp.StatusCode != http.StatusOK {
		log.Println("HTTP status code", resp.StatusCode)
		return false, fmt.Errorf("flag validation returned HTTP status code %d", resp.StatusCode)
	}

	var validateResponse ValidateResponse
	err = json.NewDecoder(resp.Body).Decode(&validateResponse)
	if err != nil {
		log.Println(err)
		return false, err
	}

	return validateResponse.Correct, nil
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

	runtimeResults, err := doRuntimeCheck()
	if err != nil {
		log.Println(err)
		return
	}

	// TODO
	validateResult, err := validateFlag()
	if err != nil {
		log.Println(err)
		return
	}

	gradescopeFormattedOutput := GradescopeOutput{
		Score: 150.0 - (4.0 * float64(len(failures))) - (60.0 - float64(runtimeResults.RuntimeGrade)),
		Tests: make([]GradescopeTest, 0, len(failures)+len(runtimeResults.Results)),
	}

	for _, failure := range failures {
		gradescopeFormattedOutput.Tests = append(
			gradescopeFormattedOutput.Tests,
			GradescopeTest{
				Score:    0,
				MaxScore: 2.0,
				Name:     fmt.Sprintf("%v", failure),
			},
		)
	}

	validateTest := GradescopeTest{
		Score:    0.0,
		MaxScore: 34.0,
		Name:     "Validate flag from Datadog",
	}
	if validateResult {
		validateTest.Score = 34.0
	}

	gradescopeFormattedOutput.Tests = append(gradescopeFormattedOutput.Tests, runtimeResults.Results...)
	gradescopeFormattedOutput.Tests = append(gradescopeFormattedOutput.Tests, validateTest)

	output, err := json.MarshalIndent(gradescopeFormattedOutput, "", "  ")
	if err != nil {
		log.Println(err)
		return
	}

	_ = os.WriteFile("/autograder/results/results.json", output, 0777)
}
