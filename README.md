# Claude Code with OpenRouter and Z.ai GLM 5.2

This repository provides a small launcher for running Claude Code through OpenRouter, defaulting to Z.ai GLM 5.2:

```text
z-ai/glm-5.2
```

It is intentionally narrow, no local model setup, no MCP servers, no private plugins, and no machine-specific configuration.

## Requirements

- Claude Code CLI: `claude`
- OpenRouter API key
- macOS/Linux: `bash`, `curl`, and `node` for model listing
- Windows: PowerShell

## Setup

Clone the repo, then create a private env file.

macOS/Linux:

```sh
cp examples/env.example ~/.claude-zai.env
chmod 600 ~/.claude-zai.env
```
