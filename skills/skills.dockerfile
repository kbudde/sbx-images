FROM scratch

# COPY agents/ /home/agent/.agents/factory/
# COPY factory/ /home/agent/.agents/factory-templates/
# COPY factory-setup.sh /home/agent/.agents/factory-setup.sh
# COPY context.md /home/agent/.agents/factory-context.md
COPY opencode /import/skills
