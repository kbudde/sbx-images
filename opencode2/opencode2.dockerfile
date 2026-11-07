# hadolint ignore=DL3007
FROM docker.io/sbx/opencode-image:latest@sha256:4373c3fb3804d65051b5b05a244d7f0b9c4dc14a3fea637c252e72b0bceb2539
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
