# AI Tools

This sandbox includes additional AI tools for common coding workflows.

## Serena

Serena is an MCP toolkit for semantic code editing. It provides IDE-like
capabilities — symbol-level navigation, refactoring, and debugging — through
the Model Context Protocol.

- **When to use**: For complex code navigation, refactoring, or debugging
  tasks that require understanding code structure at the symbol level.
- **How to use**: Serena runs as an MCP server. Configure your agent to
  connect to it.
- **Initialization**: Already initialized with `serena init` during build.
- **Do to use**: If working with files outside of the project or non code files.

## Archify

Archify is an agent skill for generating beautiful, verifiable architecture
diagrams as interactive HTML files.

- **When to use**: When you need to visualize system architecture, workflows,
  sequence diagrams, data flows, or lifecycle diagrams.
- **How to use**: Describe the system you want to diagram. Archify generates
  a self-contained interactive HTML file and verifies the diagram before
  delivering it.
