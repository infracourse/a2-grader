FROM --platform=linux/amd64 golang:1.21 as builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o run_autograder

# ---------------------------------------------------------------------

FROM --platform=linux/amd64 gradescope/autograder-base:ubuntu-22.04

COPY --from=builder /app/run_autograder /autograder/run_autograder
