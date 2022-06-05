FROM ubuntu:18.04

###########################
# START: Global ENV Setup #
###########################

# Versions and Arch
ENV PYTHON_VERSION='3.8'
ENV AWS_KUBERNETES_VERSION='1.19.6/2021-01-05'
ENV TERRAFORM_VERSION='1.2.2'
ENV TARGETARCH='amd64'
ENV VENV_DIR='/opt/venv'
ENV PY_REQUIREMENTS='requirements.txt'

# Locale Support
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Setup Prompt Variable
ARG PS1='export PS1="\[\033[01;32m\]@cicd_environemnt: \[\033[0m\]\w \$ "'
RUN echo $PS1 >> /etc/bash.bashrc
RUN echo $PS1 >> /root/.bashrc

#########################
# END: Global ENV Setup #
#########################

#########################
# START: Linux Packages #
#########################

ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes
RUN apt-get update

# Install general packages, these do not require specific setup
RUN apt-get install -y \
    wget \
    unzip \
    less \
    ca-certificates \
    curl \
    software-properties-common \
    jq \
    git \
    iputils-ping \
    libcurl4 \
    libicu60 \
    libunwind8 \
    netcat \
    libssl1.0 \
    apt-transport-https \
    gnupg \
    lsb-release \
    make \
    gcc \
    tzdata \
    vim \
    locales \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-venv \
    python3-pip

# APT SETUP for Specific Packages: Docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# RUN a single APT-GET UPDATE after APT SETUP blocks
RUN apt-get update

# APT INSTALL for Specific Packages: Java
RUN apt-get install -y openjdk-8-jdk
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

# APT INSTALL for Specific Packages: Docker
RUN apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io

# NOTE: Use only one one List remove to avoid long docker build
RUN rm -rf /var/lib/apt/lists/*

#######################
# END: Linux Packages #
#######################

#################################
# START: Setup NON-APT Packages #
#################################

# Setup Python Virtual Environment
RUN python${PYTHON_VERSION} -m venv ${VENV_DIR}
RUN . ${VENV_DIR}/bin/activate &&\
    pip install --upgrade pip &&\
    pip install wheel

RUN echo "source ${VENV_DIR}/bin/activate &&\
    if [ -f \"${PY_REQUIREMENTS}\" ]; then pip3 install -r ${PY_REQUIREMENTS};fi" \
    > /bin/venv

# Update Pip before installing python packages
RUN python${PYTHON_VERSION} -m pip install --upgrade pip

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" &&\
    unzip awscliv2.zip &&\
    ./aws/install

# install kubectl
RUN curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/${AWS_KUBERNETES_VERSION}/bin/linux/amd64/kubectl &&\
    chmod +x ./kubectl &&\
    mv kubectl /usr/local/bin/

# Install eksctl
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp &&\
    mv /tmp/eksctl /usr/local/bin

# Install Terraform
RUN wget --quiet https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip &&\
    unzip terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip &&\
    mv terraform /usr/bin &&\
    rm terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip &&\
    ln -s /usr/bin/terraform /usr/bin/tf &&\
    export USER=root &&\
    touch ~/.bashrc &&\
    tf -install-autocomplete

###############################
# END: Setup NON-APT Packages #
###############################

# ENTRYPOINT, init docker for Docker-In-Docker capabilities
ENTRYPOINT service docker start
