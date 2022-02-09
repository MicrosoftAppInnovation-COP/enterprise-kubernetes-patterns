FROM ubuntu:20.04

RUN apt-get update && apt-get -y install curl \
    iputils-ping \
    apt-transport-https \
    tar \
    jq \
    software-properties-common \
    wget \
    gnupg2 \
    python && \
    apt-get clean && apt-get autoremove

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh
ENTRYPOINT ["/actions-runner/entrypoint.sh"]