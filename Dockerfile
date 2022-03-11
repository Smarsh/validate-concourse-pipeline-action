FROM alpine:latest

RUN apk update --no-cache && apk add wget bash nodejs-current npm git jq perl

RUN wget https://github.com/mikefarah/yq/releases/download/3.2.1/yq_linux_amd64 && mv yq_linux_amd64 /usr/bin/yq && chmod +x /usr/bin/yq

RUN wget https://github.com/concourse/concourse/releases/download/v7.6.0/fly-7.6.0-linux-amd64.tgz && \
    tar xf fly*.tgz -C /usr/bin/ && \
    chmod +x /usr/bin/fly

RUN wget https://github.com/cuelang/cue/releases/download/v0.4.0/cue_v0.4.0_linux_amd64.tar.gz && \
    tar xf cue*.tar.gz -C /usr/bin/ && \
    chmod +x /usr/bin/cue

RUN npm install https://github.com/RealOrko/nodejs-handlebars-cli.git -g --force

COPY validate.sh /validate.sh
COPY checkenv.sh /checkenv.sh

CMD [ "bash", "/validate.sh" ]
