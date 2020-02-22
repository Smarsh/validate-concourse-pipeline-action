FROM alpine

RUN apk add --update --no-cache \
    ca-certificates \
    wget \
    bash 
    
RUN wget https://github.com/concourse/concourse/releases/download/v5.8.0/fly-5.8.0-linux-amd64.tgz && \
    tar xf fly*.tgz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/fly

COPY entrypoint.sh /entrypoint.sh

CMD ["sh", "/entrypoint.sh"]

