# nordic-geno-epimight: the kit that runs EPIMIGHT across the Nordic registers
# Upstream: https://github.com/rwaples/nordic-geno-epimight (release tag NGE_REF)
#
# The Docker image of the kit (ADR 0006), in the layout of BioPsyk/imagelib, where a copy
# of this folder lives as images/nordic-geno-epimight/. It runs the same install as the
# README and the Apptainer recipe (container/nordicepimight.def): the environment of
# pixi.lock, the R packages of kit/nordicepimight/inst/pins.yaml, and the unit tests.
# The lock covers linux-64 only, so the image is amd64, as regenie's is.

FROM --platform=linux/amd64 ghcr.io/prefix-dev/pixi@sha256:022f8a2ca2fa6c226461b6b4b07ac7287bf9feb1db0ad3008dd3e8a6ed1b38a4

ARG DEBIAN_FRONTEND=noninteractive
# The kit release this image holds. The docker workflow checks on each v* tag that this
# default is that tag, so imagelib's copy builds the release CI tested; bump it, and
# VERSION, at each release.
ARG NGE_REF=v0.1.0

LABEL org.opencontainers.image.title="nordic-geno-epimight" \
      org.opencontainers.image.description="Runs EPIMIGHT heritability and genetic-correlation analyses on Nordic register pedigrees" \
      org.opencontainers.image.source="https://github.com/rwaples/nordic-geno-epimight"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/*

# A full clone, so `git describe` finds the release tag; NGE_REF may be a tag, a branch or
# a commit. The kit records the version and commit in every run.yaml. IMAGE_VERSION is
# written after the unit tests: it marks the kit as running in an image (R/steps.R).
# setup downloads EPIMIGHT and pedigreegraph through the GitHub API, which allows 60
# anonymous requests an hour per address; a build given the secret github_pat
# (--secret id=github_pat,env=GITHUB_PAT) uses that token, which stays out of the image.
RUN --mount=type=secret,id=github_pat,env=GITHUB_PAT git clone https://github.com/rwaples/nordic-geno-epimight.git /opt/kit \
    && cd /opt/kit \
    && git checkout --detach "${NGE_REF}" \
    && export KIT_COMMIT=$(git rev-parse HEAD) KIT_VERSION=$(git describe --tags --always) \
    && export PIXI_CACHE_DIR=/var/tmp/pixi-cache CARGO_HOME=/var/tmp/cargo \
    && pixi install --locked \
    && pixi run --locked setup \
    && pixi run --locked test \
    && pixi run --locked fc-cache -f \
    && echo "$KIT_COMMIT" > /opt/kit/IMAGE_REVISION \
    && echo "$KIT_VERSION ($KIT_COMMIT)" > /opt/kit/IMAGE_VERSION \
    && install -m 0755 container/nordicepimight /usr/local/bin/nordicepimight \
    && rm -rf .git "$PIXI_CACHE_DIR" "$CARGO_HOME" /root/.cache

# What users type before a command, which the kit's messages name (R/steps.R). The kit's
# own environment, R's isolation from the host included, is set by
# container/nordicepimight, which every command runs through.
ENV KIT_COMMAND=nordicepimight \
    HOME=/tmp

COPY VERSION /etc/nordic-geno-epimight-version-tag
RUN { \
      echo "nordic-geno-epimight $(cat /opt/kit/IMAGE_VERSION)"; \
      echo "Image $(tr -d '[:space:]' < /etc/nordic-geno-epimight-version-tag)"; \
      /opt/kit/.pixi/envs/default/bin/Rscript -e 'cat(R.version.string, "\n")'; \
      /opt/kit/.pixi/envs/default/bin/Rscript -e 'for (p in c("epimight", "pedigreegraph", "nordicepimight")) cat(p, format(packageVersion(p)), "\n")'; \
      nordicepimight pedsum --version; \
    } > /etc/nordic-geno-epimight-version

WORKDIR /data

RUN groupadd --system kit \
    && useradd --system --gid kit --home-dir /tmp kit \
    && chown kit:kit /data
USER kit

CMD ["nordicepimight", "help"]
