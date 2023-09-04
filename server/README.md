# QueryDesk Server

Instructions for running self hosted install of QueryDesk. Currently only k8s install is supported, reach out to support@querydesk.com if you would like additional methods supported.

*Requires Enterprise plan.*

## Installation

1. Get an api key from https://app.querydesk.com/settings/api-keys

1. Setup a postgres database and take note of credentials.

1. create k8s secret

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: querydesk
      namespace: querydesk
    type: Opaque
    data:
      ### REQUIRED ###

      CLOAK_KEY_V1: # 32 random bytes base64 encoded (used for encrypting senstive fields in the database)
      DB_PASSWORD: 
      LICENSE_KEY: # use api key created in first step
      SECRET_KEY_BASE: # generate random secure value

      ### OPTIONAL ###

      # Database SSL (if enabled)
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

1. Install with helm

    ```bash
    # make sure to use helm 3.8.0 or later, or set `export HELM_EXPERIMENTAL_OCI=1`
    helm install querydesk oci://ghcr.io/querydesk/helm-charts/server --version x.x.x \
      --set querydesk.configSecretName=querydesk \
      --set env.DB_HOSTNAME=${database IP from earlier setup} \
      --set env.DB_USERNAME=${username to use to connect to database} \
      --set env.DB_SSL=true \ # if you want to enable SSL
      --set env.HOST=${url where your install will be accessible, for example app.querydesk.com} \
      --namespace querydesk
    ```

## Changelog

### 1.3.2

fix: Handle license renewal

### 1.3.0

feature: Data Protection
fix: Format UUIDs properly in relationship field

### 1.2.2

feature: Add GraphQL support for credentials

### 1.2.1

feature: Add GraphQL API to enable terraform provider

### 1.2.0

First self hosted release
