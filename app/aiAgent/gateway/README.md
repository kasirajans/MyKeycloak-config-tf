# Gateway Keycloak clients (ai-gateway, mcp-gateway)

Keycloak client config for the two gateways built and deployed outside this repo:
ai-gateway (entry point for human-to-agent and A2A traffic) and mcp-gateway (fronts the
individual MCP servers, only ever called by ai-gateway). This directory configures
Terraform/Keycloak resources only — the gateways' own code/deployment lives elsewhere.

Real Keycloak mechanics (Standard Token Exchange V2, GA by default) — corrected from an
earlier draft that assumed a fine-grained 'permitted to exchange to' permission, which
does NOT exist for V2:
- A client can only exchange a subject_token for a new token targeted at a different
  client in the SAME realm; no user impersonation, no external-token exchange.
- The subject_token presented must already carry the requesting client (ai-gateway, or
  mcp-gateway) in its own aud claim — that requirement, not an admin permission, is what
  restricts who can exchange through whom. exchange_targets in ai-gateway.yaml /
  mcp-gateway.yaml above drives the aud/client-scope wiring that makes this true, plus
  optional Client Policies for extra conditions.
- Keycloak's GA token exchange does NOT add an act/sub delegation claim identifying both
  the human and the agent. If that's a hard requirement, evaluate Keycloak's
  experimental, opt-in 'Token Exchange Delegation' feature (may_act claim — not GA, can
  change) versus writing a custom protocol mapper to stamp an equivalent claim yourself.
  This is an open decision — do not assume either exists until it's built and tested.
