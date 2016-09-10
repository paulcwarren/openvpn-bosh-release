FROM alpine:latest
RUN apk --no-cache add ca-certificates coreutils curl git \
  && curl -Lo /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 && chmod +x /usr/local/bin/jq
ADD assets /opt/resource
ADD blob /opt/resource/blob
