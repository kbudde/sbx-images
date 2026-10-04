FROM docker.io/sbx/opencode-image:latest
ARG OPENCODE_VERSION
#USER root
#RUN npm install -g @opencode/cli --force

USER agent
# ENV OPENCODE_CONFIG_DIR=/home/agent/.config/opencode
# RUN npm uninstall -g opencode-ai \
#     && npm install -g "@opencode/cli@${OPENCODE_VERSION}" \
#     && npm cache clean --force \
#     && opencode --version
#ENTRYPOINT []
# CMD ["opencode"]