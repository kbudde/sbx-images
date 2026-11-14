# hadolint ignore=DL3007
FROM docker.io/sbx/opencode-image:latest@sha256:f03153f04e4cd4146b201ed25afc71c80c779aa08164c5c6aa75f0ae72168c44
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
