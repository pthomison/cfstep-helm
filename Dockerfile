FROM golang:latest as setup

ARG KUBE_VERSION="v1.15.1"
ARG HELM_VERSION="v2.14.0"

RUN curl -L "https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o helm.tar.gz \
  && tar -xf helm.tar.gz \
  && mv ./linux-amd64/helm /usr/local/bin/helm \
  && helm init --client-only

RUN helm plugin install https://github.com/hypnoglow/helm-s3.git \
  && helm plugin install https://github.com/nouney/helm-gcs.git \
  && helm plugin install https://github.com/chartmuseum/helm-push.git

# Run acceptance tests
COPY Makefile Makefile
COPY bin/ bin/
COPY lib/ lib/
COPY acceptance_tests/ acceptance_tests/
RUN apt-get update \
    && apt-get install -y python3-venv \
    && make acceptance


# Cloning https://github.com/codefresh-io/kubectl-helm/blob/master/Dockerfile but for fedora
FROM fedora:30

ARG KUBE_VERSION="v1.15.1"
ARG HELM_VERSION="v2.14.0"

ENV FILENAME="helm-${HELM_VERSION}-linux-amd64.tar.gz"

RUN echo ${FILENAME}

RUN dnf update -y
RUN dnf install -y \
  ca-certificates \
  curl \
  bash \
  jq \
  python2 \
  python3 \
  make \
  git \
  openssl \
  python2-pip \
  python3-pip \
  && pip install yq \
  && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
  && chmod +x /usr/local/bin/kubectl \
  && curl -L http://storage.googleapis.com/kubernetes-helm/${FILENAME} -o /tmp/${FILENAME} \
  && tar -zxvf /tmp/${FILENAME} -C /tmp \
  && mv /tmp/linux-amd64/helm /bin/helm \
  && rm -rf /tmp/*

RUN helm init --client-only
WORKDIR /config

COPY --from=setup /root/.helm/ /root/.helm/
COPY bin/* /opt/bin/
RUN chmod +x /opt/bin/*
COPY lib/* /opt/lib/

ENV HELM_VERSION ${HELM_VERSION}

ENTRYPOINT ["/opt/bin/release_chart"]
