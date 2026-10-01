# Identity Provider configuration

Identity provider (IdP) trust relationships between realms and external/internal IdPs. Low volume — same pattern as config/realm/: one idp-providers.yml listing all providers, read by main.tf via for_each, rather than a directory per provider. TODO: not built yet.
