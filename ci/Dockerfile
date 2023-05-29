# Usage:
#   docker build -t chaitin/safeline-detector:t1k-ci-latest .
#   docker push chaitin/safeline-detector:t1k-ci-latest
FROM chaitin/safeline-detector:latest

RUN sed -i "s/^# bind_addr/bind_addr/; s/^# listen_port/listen_port/; s/^bind_addr: unix/# bind_addr: unix/;" /detector/snserver.yml
