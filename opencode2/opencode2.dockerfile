# hadolint ignore=DL3007
FROM docker.io/sbx/opencode-image:latest@sha256:7b2927a5b648f5e6799a9d8aab5710f34c176292ab28eedb651c02b5ef9c1508
ARG OPENCODE_VERSION

USER agent
ENV OPENCODE_CONFIG_DIR=/home/agent/.config/opencode
RUN curl -fsSL https://opencode.ai/v2/install -o /tmp/opencode-install.sh \
  && bash /tmp/opencode-install.sh --version ${OPENCODE_VERSION} \
  && rm -f /tmp/opencode-install.sh
# hadolint ignore=DL3064
ENV OPENCODE_PASSWORD="localbox"
COPY start.sh /start.sh
ENTRYPOINT ["/start.sh"]
