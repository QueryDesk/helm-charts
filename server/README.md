# QueryDesk Server

create k8s secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: querydesk
  namespace: querydesk
type: Opaque
data:
  # REQUIRED

  CLOAK_KEY_V1: # 32 random bytes base64 encoded (used for encrypting senstive fields in the database)
  DB_PASSWORD: 
  LICENSE_KEY: # provided as part of subscription
  SECRET_KEY_BASE: # generate random secure value

  # OPTIONAL

  # Database SSL
  ca.cert:
  client.key:
  client.cert:

  # Google auth provider
  GOOGLE_CLIENT_ID:
  GOOGLE_CLIENT_SECRET:

  # GitHub auth provider
  GITHUB_CLIENT_ID:
  GITHUB_CLIENT_SECRET:

  # OIDC auth provider
  OIDC_DISCOVERY_DOCUMENT_URI:
  OIDC_CLIENT_ID:
  OIDC_CLIENT_SECRET:
```

## Changelog

### 1.3.0

feature: Data Protection
fix: Format UUIDs properly in relationship field

### 1.2.2

feature: Add GraphQL support for credentials

### 1.2.1

feature: Add GraphQL API to enable terraform provider

### 1.2.0

First self hosted release
