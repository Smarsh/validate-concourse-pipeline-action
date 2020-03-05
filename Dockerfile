FROM alpine

RUN apk update && apk add wget bash

RUN wget https://github.com/mikefarah/yq/releases/download/3.2.1/yq_linux_amd64 && mv yq_linux_amd64 /usr/bin/yq && chmod +x /usr/bin/yq

COPY validate.sh /validate.sh

CMD [ "sh", "/validate.sh" ]

