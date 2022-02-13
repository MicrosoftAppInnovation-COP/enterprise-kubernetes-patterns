FROM summerwind/actions-runner:latest

RUN sudo apt update -y \
  && sudo apt install maven -y \
  && curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
  && sudo rm -rf /var/lib/apt/lists/*