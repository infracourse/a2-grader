FROM --platform=linux/arm64 golang:1.21-alpine as builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o synthesizer

# ---------------------------------------------------------------------

FROM --platform=linux/arm64 public.ecr.aws/lambda/provided:al2023-arm64

RUN dnf install -y python3 python3-pip nodejs npm

COPY cdk_requirements.txt cdk_requirements.txt
RUN pip install -r cdk_requirements.txt

RUN npm install -g aws-cdk

WORKDIR /app

COPY --from=builder /app/synthesizer synthesizer

ENTRYPOINT [ "./synthesizer" ]
