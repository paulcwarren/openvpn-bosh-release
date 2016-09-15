FROM ubuntu:trusty
RUN apt-get update && apt-get install -y curl git && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && curl -Lo /usr/local/bin/bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-0.0.61-linux-amd64 && chmod +x /usr/local/bin/bosh
