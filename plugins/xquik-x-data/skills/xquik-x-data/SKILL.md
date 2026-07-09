---
name: xquik-x-data
description: >
  Use when a user needs Xquik API or remote MCP guidance for X data extraction,
  monitoring, webhooks, search, or automation workflows. Triggers: Xquik,
  X data, account monitor, keyword monitor, webhook, remote MCP.
---

# Xquik X Data

Use this skill when planning or reviewing a workflow that uses Xquik's public API, docs, or remote MCP endpoint.

## Source Truth

Start with public sources before writing requests or integration steps:

- Product docs: https://docs.xquik.com/api-reference/overview
- OpenAPI: https://xquik.com/openapi.json
- Remote MCP endpoint: https://xquik.com/mcp
- GitHub: https://github.com/Xquik-dev/x-twitter-scraper

## Process

1. Identify whether the user needs REST API, webhook, monitor, search, or remote MCP guidance.
2. Read the public docs or OpenAPI before naming endpoints, request fields, response fields, or limits.
3. Keep API keys and account credentials out of prompts, examples, logs, and committed files.
4. Use the remote MCP endpoint only when the user's MCP client supports authenticated remote servers.
5. Prefer small, testable examples that show one workflow at a time.
6. State unsupported or unverified behavior as unknown instead of inventing details.

## Common Mistakes

| Avoid | Prefer |
| --- | --- |
| Inventing endpoint names from memory | Check the OpenAPI document first |
| Pasting API keys into examples | Use placeholders such as `<XQUIK_API_KEY>` |
| Mixing REST and MCP setup steps | Pick the integration path first |
| Describing private routing internals | Refer only to public API, docs, and MCP behavior |
