# api-tests

A Postman collection for testing the authorization code + PKCE login against each realm.
It's in Postman's v2.1 format, which both Postman and Bruno import.

| File | What it is |
|---|---|
| `keycloak-pkce.postman_collection.json` | The requests. Realm-independent: every URL is built from environment variables. |
| `home-human-automation.postman_environment.json` | Environment for the `home-human-automation` realm, client `app`. |
| `customer.postman_environment.json` | Environment for the `customer` realm. Set `clientId` once that realm has a public client. |

`ai-agent` has no environment: its clients are machine-to-machine only and never log a
user in through a browser, so PKCE doesn't apply.

## Import

**Postman:** Import → drop in all three files. Pick the realm in the environment selector
(top right).

**Bruno:** Import Collection → Postman Collection → `keycloak-pkce.postman_collection.json`.
Then Collection settings → Environments → Import → Postman Environment, once per
environment file. Bruno converts the `pm.*` scripts to its own; if a converted script
fails, use the step-by-step folder and set variables by hand.

## Environment variables

| Variable | Default | Change it when |
|---|---|---|
| `baseUrl` | `http://localhost:8080` | Keycloak runs elsewhere. Use the URL a **browser** reaches (the external/NAT port), not Terraform's internal one. |
| `realm` | the realm's name | Never. One environment per realm. |
| `clientId` | `app` / `CHANGE-ME` | Testing another public client. File name in `app/<realm>/public/`. |
| `redirectUri` | `http://localhost:3000/callback` | It must match one of the client's `redirect_uris` (`app.yaml` allows `http://localhost:3000/*`). |
| `scope` | `openid profile email` | You need other scopes. |

The rest (`codeVerifier`, `authCode`, `accessToken`, ...) are filled in by the requests.

## Two ways to log in

Log in as a user from `users/<realm>/users/users.yml`. To read their password, see
"Reading a user's password" in `users/home-human-automation/README.md`.

### A. Built-in OAuth2 helper (quickest)

Open the folder **A. Built-in OAuth2 helper** → Auth tab → **Get New Access Token** → log in
in the popup → **Use Token** → send **Userinfo**.

It's set to log in inside Postman's own window ("Authorize using browser" off), so the
`localhost:3000` redirect URI works as-is. If you switch to "Authorize using browser",
Postman uses `https://oauth.pstmn.io/v1/callback`, which you'd first have to add to the
client's `redirect_uris`.

### B. Manual PKCE flow (see every step)

1. **Build login URL** — generates a new `codeVerifier` / `codeChallenge` / `state` and
   prints the login URL in the console (also saved as `loginUrl`). Open it in a browser
   and log in. The browser is then sent to
   `http://localhost:3000/callback?state=...&code=...`; the page won't load if nothing
   runs there, which is fine. Copy the `code` value into `authCode`, and check `state`
   matches the environment's `state`.
2. **Exchange code for tokens** — within about a minute (codes expire fast and work
   once). Saves `accessToken`, `refreshToken`, `idToken`.
3. **Userinfo** — proves the access token works.
4. **Refresh tokens** — gets new tokens without logging in again.
5. **Logout** — ends the Keycloak session and clears the saved tokens.

To see what's inside a token (roles, groups, audience), paste `accessToken` into a JWT
decoder you trust. Prefer one that decodes locally, since the token is a credential.

## Common errors

| Error | Cause |
|---|---|
| `Invalid parameter: redirect_uri` | `redirectUri` isn't in the client's `redirect_uris`. |
| `Client not found` | Wrong `clientId`, or the client isn't applied in this realm. |
| `invalid_grant: Code not valid` | The code expired or was already used. Start again at step 1. |
| `invalid_grant: PKCE verification failed` | Step 1 was re-run after you logged in, so `codeVerifier` changed. Start again at step 1. |

A user with a temporary password (the default) is asked to set a new one on the Keycloak
login page before the redirect; that's expected.
