FROM docker.io/sbx/opencode-image:latest
ARG OPENCODE_VERSION

USER agent
ENV OPENCODE_CONFIG_DIR=/home/agent/.config/opencode
RUN curl -fsSL https://opencode.ai/v2/install | bash -s -- --version ${OPENCODE_VERSION}
ENV OPENCODE_PASSWORD="localbox"
ADD start.sh /start.sh
ENTRYPOINT ["/start.sh"]