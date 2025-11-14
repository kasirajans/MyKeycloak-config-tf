# Single Logout (SLO) Implementation Guide

This guide explains how to implement Single Logout across the federated Keycloak setup (SP-Customer → IdP-Customer).

## 🔄 Logout Flow

```
[User clicks Logout in SPA]
     │
     ├─► 1. SPA clears local tokens from storage
     │      - sessionStorage.removeItem('access_token')
     │      - sessionStorage.removeItem('id_token')
     │
     ├─► 2. SPA redirects to SP-Customer logout endpoint
     │      GET /realms/sp-customer/protocol/openid-connect/logout
     │      + id_token_hint (user's ID token)
     │      + post_logout_redirect_uri (where to go after logout)
     │
     ├─► 3. SP-Customer (Keycloak B) logs out user
     │      - Invalidates SP-Customer session
     │      - Checks if user logged in via IdP
     │
     ├─► 4. SP-Customer calls IdP-Customer logout (backchannel)
     │      POST /realms/idp-customer/protocol/openid-connect/logout
     │      - Invalidates IdP-Customer session
     │
     ├─► 5. IdP-Customer clears session
     │      - User logged out from IdP-Customer
     │      - Session tokens revoked
     │
     ├─► 6. SP-Customer receives confirmation
     │      - Completes logout process
     │
     └─► 7. User redirected to post_logout_redirect_uri
           - SPA shows "logged out" page
           - User can login again
```

## 📝 SPA Implementation

### JavaScript/TypeScript Example

```javascript
// logout.js

// Configuration
const KEYCLOAK_URL = 'http://localhost:8080';
const REALM = 'sp-customer';
const CLIENT_ID = 'YOUR_CLIENT_UUID'; // From terraform output
const POST_LOGOUT_REDIRECT_URI = 'http://localhost:5173/logged-out';

/**
 * Perform Single Logout
 */
function logout() {
  // 1. Get ID token from storage
  const idToken = sessionStorage.getItem('id_token');
  
  // 2. Clear tokens from local storage
  sessionStorage.removeItem('access_token');
  sessionStorage.removeItem('refresh_token');
  sessionStorage.removeItem('id_token');
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  localStorage.removeItem('id_token');
  
  // 3. Build logout URL
  const logoutUrl = new URL(
    `${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/logout`
  );
  
  // 4. Add query parameters
  const params = {
    post_logout_redirect_uri: POST_LOGOUT_REDIRECT_URI,
    client_id: CLIENT_ID
  };
  
  // Add id_token_hint if available (recommended)
  if (idToken) {
    params.id_token_hint = idToken;
  }
  
  // Append parameters to URL
  Object.keys(params).forEach(key => 
    logoutUrl.searchParams.append(key, params[key])
  );
  
  // 5. Redirect to logout endpoint
  window.location.href = logoutUrl.toString();
}

/**
 * Example: Logout button handler
 */
document.getElementById('logout-btn').addEventListener('click', (e) => {
  e.preventDefault();
  logout();
});
```

### React Example

```jsx
// hooks/useAuth.js
import { useCallback } from 'react';

const KEYCLOAK_CONFIG = {
  url: 'http://localhost:8080',
  realm: 'sp-customer',
  clientId: 'YOUR_CLIENT_UUID',
  postLogoutRedirectUri: 'http://localhost:5173/logged-out'
};

export function useAuth() {
  const logout = useCallback(() => {
    // Get ID token
    const idToken = sessionStorage.getItem('id_token');
    
    // Clear all tokens
    sessionStorage.clear();
    localStorage.clear();
    
    // Build logout URL
    const logoutUrl = new URL(
      `${KEYCLOAK_CONFIG.url}/realms/${KEYCLOAK_CONFIG.realm}/protocol/openid-connect/logout`
    );
    
    const params = new URLSearchParams({
      post_logout_redirect_uri: KEYCLOAK_CONFIG.postLogoutRedirectUri,
      client_id: KEYCLOAK_CONFIG.clientId
    });
    
    if (idToken) {
      params.append('id_token_hint', idToken);
    }
    
    // Redirect
    window.location.href = `${logoutUrl}?${params.toString()}`;
  }, []);
  
  return { logout };
}

// Component usage
function LogoutButton() {
  const { logout } = useAuth();
  
  return (
    <button onClick={logout}>
      Logout
    </button>
  );
}
```

### Angular Example

```typescript
// services/auth.service.ts
import { Injectable } from '@angular/core';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private readonly config = {
    keycloakUrl: 'http://localhost:8080',
    realm: 'sp-customer',
    clientId: 'YOUR_CLIENT_UUID',
    postLogoutRedirectUri: 'http://localhost:4200/logged-out'
  };
  
  logout(): void {
    // Get ID token
    const idToken = sessionStorage.getItem('id_token');
    
    // Clear tokens
    sessionStorage.clear();
    localStorage.clear();
    
    // Build logout URL
    const logoutUrl = new URL(
      `${this.config.keycloakUrl}/realms/${this.config.realm}/protocol/openid-connect/logout`
    );
    
    const params = new URLSearchParams({
      post_logout_redirect_uri: this.config.postLogoutRedirectUri,
      client_id: this.config.clientId
    });
    
    if (idToken) {
      params.append('id_token_hint', idToken);
    }
    
    // Redirect
    window.location.href = `${logoutUrl}?${params.toString()}`;
  }
}

// Component
@Component({
  selector: 'app-logout-button',
  template: '<button (click)="authService.logout()">Logout</button>'
})
export class LogoutButtonComponent {
  constructor(public authService: AuthService) {}
}
```

## ⚙️ Keycloak Configuration

### 1. Update PKCE Client Configuration

Add valid post-logout redirect URIs to your `apps.yaml`:

```yaml
# File: app/sp-customer/pkce/apps.yaml
realm: sp-customer

clients:
  - client_id: mobile-web-app-broker
    name: "Mobile/Web App Broker Client"
    enabled: true
    
    pkce:
      challenge_method: S256
    
    # Redirect URIs for login
    redirect_uris:
      - http://localhost:5173/callback
      - http://localhost:3000/callback
      - http://localhost:8081/callback
      - http://localhost:4200/callback
    
    # Web origins for CORS
    web_origins:
      - http://localhost:5173
      - http://localhost:3000
      - http://localhost:8081
      - http://localhost:4200
    
    # Valid post-logout redirect URIs
    valid_post_logout_redirect_uris:
      - http://localhost:5173/logout
      - http://localhost:5173/
      - http://localhost:3000/logged-out
      - http://localhost:3000/
      - http://localhost:8081/logged-out
      - http://localhost:4200/logged-out
    
    token_settings:
      access_token_lifespan: 300
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    
    consent_required: false
    
    mappers:
      - type: user_attribute
        name: email
        user_attribute: email
        claim_name: email
      - type: audience
        name: audience
        audience: self
```

### 2. Update Terraform to Support Post-Logout URIs

Edit `app/sp-customer/pkce/main.tf`:

```hcl
# PKCE Clients - Authorization Code Flow with PKCE (for Web/Mobile Apps)
resource "keycloak_openid_client" "pkce" {
  for_each = local.clients
  
  lifecycle {
    ignore_changes = [name]
  }

  realm_id  = local.config.realm
  client_id = random_uuid.client[each.key].result
  name      = each.value.name
  enabled   = each.value.enabled

  access_type           = "PUBLIC"
  standard_flow_enabled = true
  direct_access_grants_enabled = false
  implicit_flow_enabled = false
  service_accounts_enabled = false

  # PKCE Configuration
  pkce_code_challenge_method = each.value.pkce.challenge_method

  valid_redirect_uris = each.value.redirect_uris
  web_origins         = each.value.web_origins
  
  # Post-logout redirect URIs (NEW)
  valid_post_logout_redirect_uris = lookup(each.value, "valid_post_logout_redirect_uris", [])

  # Token settings
  access_token_lifespan       = tostring(each.value.token_settings.access_token_lifespan)
  client_session_idle_timeout = tostring(each.value.token_settings.session_idle_timeout)
  client_session_max_lifespan = tostring(each.value.token_settings.session_max_lifespan)

  # Consent settings
  consent_required = each.value.consent_required
}
```

Apply the changes:
```bash
cd app/sp-customer/pkce
terraform apply -auto-approve
```

### 3. Verify IdP Configuration Has Backchannel Logout Enabled

The IdP provider configuration should already support backchannel logout. Verify in `config/idp-provider/sp-customer/main.tf`:

```hcl
resource "keycloak_oidc_identity_provider" "providers" {
  for_each = local.oidc_providers
  
  realm = local.config.realm
  alias = each.value.alias
  
  # ... other settings ...
  
  # Backchannel logout (enabled by default)
  backchannel_supported = true
  
  # ... rest of config ...
}
```

If it's set to `false`, change it to `true` or remove the line (defaults to true).

## 🔍 Testing Single Logout

### 1. Complete Login Flow

```bash
# 1. Start your app
cd /path/to/your/spa
npm run dev  # or your dev server

# 2. Open browser
open http://localhost:5173

# 3. Click login button
# 4. Login via IdP-Customer
#    - john.doe@idp-customer.com
```

### 2. Test Logout

```bash
# 1. Click logout button in your SPA
# 2. Observe the flow:
#    - Redirects to SP-Customer logout
#    - SP-Customer calls IdP-Customer logout
#    - User redirected to logged-out page

# 3. Try to access a protected page
#    - Should redirect to login
#    - Session is fully terminated
```

### 3. Verify Session Termination

Open browser developer tools:

```javascript
// Check tokens are cleared
console.log(sessionStorage.getItem('access_token')); // null
console.log(sessionStorage.getItem('id_token'));     // null

// Try to use old access token (if you saved it)
// Should get 401 Unauthorized
```

### 4. Verify Keycloak Sessions

1. Login to Keycloak Admin Console: http://localhost:8080/admin
2. Switch to `sp-customer` realm
3. Go to **Sessions** → **User sessions**
4. Should show no active sessions after logout

## 📊 Logout Endpoints

### SP-Customer Logout Endpoint
```
GET http://localhost:8080/realms/sp-customer/protocol/openid-connect/logout
  ?post_logout_redirect_uri=http://localhost:5173/logged-out
  &id_token_hint=<ID_TOKEN>
  &client_id=<CLIENT_UUID>
```

### IdP-Customer Logout Endpoint (Called by SP-Customer)
```
POST http://localhost:8080/realms/idp-customer/protocol/openid-connect/logout
  (Backchannel - called automatically by SP-Customer)
```

## 🔒 Security Considerations

### 1. Use ID Token Hint
Always include `id_token_hint` parameter:
- Prevents CSRF attacks
- Ensures correct user is logged out
- Recommended by OIDC specification

### 2. Validate Post-Logout URIs
Only register trusted URIs:
```yaml
valid_post_logout_redirect_uris:
  - http://localhost:5173/logged-out  # ✅ Specific page
  - http://localhost:5173/            # ✅ Root
  - http://evil.com/                  # ❌ Never do this
```

### 3. Clear All Storage
```javascript
// Clear everything
sessionStorage.clear();
localStorage.clear();
// Or be specific
sessionStorage.removeItem('access_token');
sessionStorage.removeItem('refresh_token');
sessionStorage.removeItem('id_token');
```

### 4. Handle Network Failures
```javascript
function logout() {
  try {
    const idToken = sessionStorage.getItem('id_token');
    
    // Clear tokens first (important!)
    sessionStorage.clear();
    
    // Then redirect to logout
    const logoutUrl = buildLogoutUrl(idToken);
    window.location.href = logoutUrl;
  } catch (error) {
    console.error('Logout error:', error);
    // Still clear tokens even if redirect fails
    sessionStorage.clear();
    window.location.href = '/logged-out';
  }
}
```

## 🛠️ Troubleshooting

### Issue: "Invalid post_logout_redirect_uri"

**Cause**: URI not registered in client configuration

**Solution**: Add URI to `valid_post_logout_redirect_uris` in `apps.yaml`

### Issue: Session Still Active After Logout

**Cause**: Backchannel logout not working

**Solution**: Verify `backchannel_supported = true` in IdP configuration

### Issue: User Not Logged Out from IdP

**Cause**: SP-Customer not configured to propagate logout

**Solution**: Check IdP provider has `store_token: true` in `idpprovider.yml`

### Issue: Redirect Loop After Logout

**Cause**: App trying to access protected resource after logout

**Solution**: Ensure logged-out page is public and doesn't require authentication

## 📝 Complete Example

### Logged Out Page (logged-out.html)

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Logged Out</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: #f5f5f5;
    }
    .container {
      text-align: center;
      padding: 2rem;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    h1 { color: #333; }
    p { color: #666; }
    button {
      margin-top: 1rem;
      padding: 0.75rem 1.5rem;
      background: #007bff;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 1rem;
    }
    button:hover {
      background: #0056b3;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>✓ Logged Out Successfully</h1>
    <p>You have been successfully logged out from all systems.</p>
    <button onclick="window.location.href='/'">
      Return to Home
    </button>
  </div>
</body>
</html>
```

## 🔗 Related

- **Main README**: See `README.md` for architecture overview
- **PKCE Configuration**: See `app/sp-customer/pkce/apps.yaml`
- **IdP Configuration**: See `config/idp-provider/sp-customer/idpprovider.yml`

---

**Key Points**:
- ✅ Always clear tokens before redirecting
- ✅ Use `id_token_hint` parameter
- ✅ Register valid post-logout URIs
- ✅ Enable backchannel logout in IdP
- ✅ Test complete logout flow
