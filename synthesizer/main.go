package main

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log"
	"maps"
	"net/http"
	"os"
	"os/exec"

	"github.com/akrylysov/algnhsa"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

func processUploadedZip(uploadedZip []byte) error {
	err := os.RemoveAll("/tmp/submission")
	if err != nil {
		log.Println(err)
		return err
	}

	err = os.MkdirAll("/tmp/submission", 0777)
	if err != nil {
		log.Println(err)
		return err
	}

	err = os.Chdir("/tmp/submission")
	if err != nil {
		log.Println(err)
		return err
	}

	zipReader, err := zip.NewReader(bytes.NewReader(uploadedZip), int64(len(uploadedZip)))
	if err != nil {
		log.Println(err)
		return err
	}

	for _, file := range zipReader.File {
		fileReader, err := file.Open()
		if err != nil {
			log.Println(err)
			return err
		}

		buff, err := io.ReadAll(fileReader)
		if err != nil {
			log.Println(err)
			return err
		}

		if file.FileInfo().IsDir() {
			os.MkdirAll(file.Name, os.ModePerm)
		} else {
			os.WriteFile(file.Name, buff, os.ModePerm)
		}
	}

	return nil
}

func synthCDK(sdkConfig aws.Config) error {
	stsSvc := sts.NewFromConfig(sdkConfig)
	result, err := stsSvc.GetCallerIdentity(context.TODO(), &sts.GetCallerIdentityInput{})
	if err != nil {
		log.Println(err)
		return err
	}
	accountID := *result.Account

	// Avoid needing to npm install / npm run build for frontend
	err = os.MkdirAll("web/dist", 0777)
	if err != nil {
		log.Println(err)
		return err
	}

	err = os.Chdir("cdk")
	if err != nil {
		return nil
	}

	// Use the lambda's hosted AWS account ID for VPC region lookups
	err = os.Setenv("CDK_DEFAULT_ACCOUNT", accountID)
	if err != nil {
		log.Println(err)
		return err
	}

	// We don't actually care about this, it's just a convenience item
	err = os.Setenv("SUNET", "cs40a2grader")
	if err != nil {
		log.Println(err)
		return err
	}

	cmd := exec.Command("cdk", "synth")
	if cmd.Err != nil {
		return cmd.Err
	}
	if err := cmd.Run(); err != nil {
		log.Println(err)
		return err
	}

	return nil
}

func concatFiles() (map[string]interface{}, error) {
	resources := make(map[string]interface{}, 100)
	for _, file := range []string{
		"cdk.out/yoctogram-dns-stack.template.json",
		"cdk.out/yoctogram-network-stack.template.json",
		"cdk.out/yoctogram-data-stack.template.json",
		"cdk.out/yoctogram-compute-stack.template.json",
	} {
		contents, err := os.ReadFile(file)
		if err != nil {
			return nil, err
		}

		var topLevelKeys map[string]interface{}
		if err := json.Unmarshal(contents, &topLevelKeys); err != nil {
			return nil, err
		}

		if resource, ok := topLevelKeys["Resources"]; ok {
			r := resource.(map[string]interface{})
			delete(r, "CDKMetadata")
			maps.Copy(resources, r)
		}
	}

	return map[string]interface{}{
		"Resources": resources,
	}, nil
}

type lambdaPayload struct {
	File []byte `json:"file"`
}

func synthHandler(w http.ResponseWriter, r *http.Request) {
	sdkConfig, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Println(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var payload lambdaPayload
	err = json.NewDecoder(r.Body).Decode(&payload)
	if err != nil {
		log.Println(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	err = processUploadedZip(payload.File)
	if err != nil {
		log.Println(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	err = synthCDK(sdkConfig)
	if err != nil {
		log.Println(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	resources, err := concatFiles()
	if err != nil {
		log.Println(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	err = json.NewEncoder(w).Encode(resources)
	if err != nil {
		log.Println(err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

func main() {
	http.HandleFunc("/", synthHandler)
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") == "" {
		http.ListenAndServe(":8000", nil)
	} else {
		algnhsa.ListenAndServe(http.DefaultServeMux, nil)
	}
}
