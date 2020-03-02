FROM debian

RUN apt-get update && apt-get install -y wget

RUN wget https://github.com/concourse/concourse/releases/download/v5.8.0/fly-5.8.0-linux-amd64.tgz && \
    tar xf fly*.tgz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/fly

RUN wget https://github.com/cloudfoundry-incubator/credhub-cli/releases/download/2.7.0/credhub-linux-2.7.0.tgz && \
    tar xf credhub*.tgz -C /usr/local/bin && \
    chmod +x /usr/local/bin/credhub

RUN wget https://github.com/mikefarah/yq/releases/download/2.4.1/yq_linux_amd64 && mv yq_linux_amd64 /usr/bin/yq && chmod +x /usr/bin/yq

COPY entrypoint.sh /entrypoint.sh

CMD ["sh", "/entrypoint.sh"]

