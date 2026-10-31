FROM docker/sandbox-templates:opencode AS build
ARG SERENA_VERSION
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
  curl ca-certificates python3 python3-venv nodejs npm \
  && rm -rf /var/lib/apt/lists/*
RUN curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh \
  && sh /tmp/uv-install.sh \
  && rm -f /tmp/uv-install.sh
ENV PATH="/root/.local/bin:${PATH}"

USER agent
# serena
RUN uv tool install -p 3.13 "serena-agent==${SERENA_VERSION}" \
  && serena init && mkdir -p /home/agent/.serena/logs \
  && sed -i 's/.*web_dashboard_listen_address: .*/web_dashboard_listen_address: 0.0.0.0/' /home/agent/.serena/serena_config.yml

# archify
RUN npx skills add tt-a1i/archify -g --agent opencode -y

FROM scratch
COPY --from=build /home/agent/.local/ /home/agent/.local/
COPY --from=build /home/agent/.agents/ /home/agent/.agents/
COPY --from=build --chown=1000 /home/agent/.serena/ /home/agent/.serena/
