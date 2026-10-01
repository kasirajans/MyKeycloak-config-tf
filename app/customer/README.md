# Customer applications

PKCE clients and roles for the customer realm — role-based access with minimal scopes, lower churn than app/aiAgent. clients/*.yaml declares one PKCE client per app, including owner_team and project fields (no per-team folder sharding here, so both must be explicit in the file); client_id is computed by main.tf as <owner_team>-<project>-<name>, same ownership convention as app/aiAgent. roles/*.yaml declares one role per file. main.tf (platform-owned) reads both via for_each.
