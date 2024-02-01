FROM --platform=linux/amd64 golang:1.21 as builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o run_autograder

# ---------------------------------------------------------------------

FROM --platform=linux/amd64 gradescope/autograder-base:ubuntu-22.04

RUN apt-get update

RUN apt-get install -y python3 python3-pip python3-dev libgl1-mesa-glx

WORKDIR /tmp

RUN wget -O chrome.deb https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/google-chrome-stable_114.0.5735.198-1_amd64.deb

RUN apt install -y ./chrome.deb

RUN wget -O chromedriver.zip https://chromedriver.storage.googleapis.com/114.0.5735.90/chromedriver_linux64.zip
RUN unzip chromedriver.zip
RUN mv chromedriver /bin

WORKDIR /autograder

COPY runtime /autograder/runtime

RUN pip3 install -r /autograder/runtime/requirements.txt

COPY --from=builder /app/run_autograder /autograder/run_autograder
