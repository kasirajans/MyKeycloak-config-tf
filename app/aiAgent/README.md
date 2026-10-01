# AI Agent applications

Client, scope, resource, and policy definitions for the AI agent identities living in the ai-agent realm: personal-ai-agent, iot-agent, iot-security-agent, and MCP/resource clients.

- resources/, scopes/, policies/, and gateway/ are API-provider/platform owned (see CODEOWNERS) — dev teams don't touch these.
- clients/<team>/ is dev-team self-service via merge request — see clients/README.md.

Delegation pattern (human -> agent -> agent/MCP) follows OAuth 2.0 Token Exchange (RFC 8693): a human's token is exchanged at the gateway/ for a short-lived delegation token (sub=human, act.sub=agent, scope narrowed, aud=one resources/ entry), re-exchanged with a narrower scope/aud at each further hop. Pure machine/digital-worker clients that never have a human in the chain use client_credentials instead; sensitive actions require CIBA (client-initiated backchannel authentication) approval — see each client's auth_pattern.

This directory owns application-level config only — realm-level config lives in config/realm/ai-agent.
