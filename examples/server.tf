resource "kubernetes_namespace_v1" "querydesk" {
  metadata {
    name = "querydesk"
  }
}

resource "helm_release" "querydesk" {
  name       = "querydesk"
  namespace  = "querydesk"
  repository = "oci://ghcr.io/querydesk/helm-charts"
  chart      = "server"
  version    = "1.3.2"
  atomic     = true

  values = [
    <<-EOF
      querydesk:
        configSecretName: querydesk
        env:
          DB_HOSTNAME: ${google_sql_database_instance.querydesk.private_ip_address}
          DB_SSL: "true" # defaults to "false"
          DB_USERNAME: ${google_sql_user.querydesk.name}
          HOST: querydesk.example.com
          # optional if you want to configure your own proxy cert, defaults to a self signed cert
          PROXY_TLS_CERT_PATH: /etc/secrets/proxy-tls/tls.crt
          PROXY_TLS_KEY_PATH: /etc/secrets/proxy-tls/tls.key
          
      proxy:
        service:
          create: true
          type: LoadBalancer

      # both of these volumes are optional depending on your needs
      volumes:
      - name: proxy-instructions
        configMap:
          name: ${kubernetes_config_map.querydesk_proxy_instructions.metadata[0].name}
      - name: proxy-tls
        secret:
          secretName: proxy.querydesk.com-tls

      volumeMounts:
      - name: proxy-instructions
        mountPath: /etc/proxy-instructions
      - name: proxy-tls
        mountPath: "/etc/secrets/proxy-tls"
        readOnly: true
    EOF
  ]

  depends_on = [
    kubernetes_namespace_v1.querydesk,
    kubernetes_secret_v1.querydesk
  ]
}

resource "kubernetes_secret_v1" "querydesk" {
  metadata {
    name      = "querydesk"
    namespace = "querydesk"
  }

  data = {
    # if you want to enable db ssl
    "ca.cert"     = google_sql_ssl_cert.querydesk.server_ca_cert
    "client.cert" = google_sql_ssl_cert.querydesk.cert
    "client.key"  = google_sql_ssl_cert.querydesk.private_key

    # required secrets
    CLOAK_KEY_V1    = "32 random bytes base64 encoded (used for encrypting senstive fields in the database)"
    DB_PASSWORD     = random_password.querydesk_db_password.result
    LICENSE_KEY     = "Get an api key from https://app.querydesk.com/settings/api-keys"
    SECRET_KEY_BASE = random_password.querydesk_secret_key_base.result

    # optional secrets
    SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/xxx/xxx/xxx"

    OIDC_CLIENT_ID              = azuread_application.querydesk.application_id
    OIDC_CLIENT_SECRET          = azuread_application_password.querydesk_client_secret.value
    OIDC_DISCOVERY_DOCUMENT_URI = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0/.well-known/openid-configuration?appid=${azuread_application.querydesk.application_id}"

    # plus any others documented in the README
  }

  depends_on = [
    kubernetes_namespace_v1.querydesk
  ]
}

# these are example instructions if you put the querydesk proxy behind cloudflare
resource "kubernetes_config_map" "querydesk_proxy_instructions" {
  metadata {
    name      = "querydesk-proxy-instructions"
    namespace = "querydesk"
  }

  data = {
    "instructions.html" = <<-EOF
      <div class="mt-2 text-slate-400">
        Run the cloudflared tunnel, try using a lower port if you run into issues.
      </div>
      <div class="rounded bg-gray-700 flex items-center p-4 mt-2">
        <div class="overflow-x-scroll mr-2">
          <code class="">
            cloudflared access tcp --hostname querydesk-proxy.example.com --url 127.0.0.1:54320
          </code>
        </div>
        <div>
          <qd-copy-to-clipboard data="cloudflared access tcp --hostname querydesk-proxy.example.com --url 127.0.0.1:54320">
          </qd-copy-to-clipboard>
        </div>
      </div>
    EOF
  }
}

resource "random_password" "querydesk_secret_key_base" {
  length  = 64
  special = true
}

# any postgres 15 instance will work, can be aws or other provider
resource "google_sql_database_instance" "querydesk" {
  name             = "querydesk"
  database_version = "POSTGRES_15"
  # ... and other settings needed
}

# the database name in the instance needs to be query_desk
resource "google_sql_database" "querydesk" {
  name     = "query_desk"
  instance = google_sql_database_instance.querydesk.name
}

resource "random_password" "querydesk_db_password" {
  length  = 64
  special = false
}

resource "google_sql_user" "querydesk" {
  name     = "querydesk"
  instance = google_sql_database_instance.querydesk.name
  type     = "BUILT_IN"
  password = random_password.querydesk_db_password.result
}

resource "google_sql_ssl_cert" "querydesk" {
  common_name = "querydesk"
  instance    = google_sql_database_instance.querydesk.name
}

# for setting up oidc with azuread
resource "azuread_application" "querydesk" {
  display_name = "QueryDesk"

  web {
    homepage_url  = "https://querydesk.example.com"
    redirect_uris = ["https://querydesk.example.com/auth/oidc/callback"]

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }
}

resource "azuread_application_password" "querydesk_client_secret" {
  application_object_id = azuread_application.querydesk.id
  display_name          = "querydesk-client-secret"
  end_date_relative     = "8760h" # 1 year
}

# the querydesk resources require an api key from an installed instance first
# https://registry.terraform.io/providers/QueryDesk/querydesk/latest/docs
provider "querydesk" {
  host    = "https://querydesk.example.com"
  api_key = "SFMyNTY.g2gDbQAAAB5rZXl..."
}

resource "querydesk_database" "demo" {
  name     = "Demo"
  adapter  = "POSTGRES"
  hostname = google_sql_database_instance.querydesk.private_ip_address
  database = "query_desk"
  # this can be set to true to require all users to be explicitly granted access (admins always have access)
  restrict_access = false

  ssl        = true
  certfile   = google_sql_ssl_cert.querydesk.cert
  keyfile    = google_sql_ssl_cert.querydesk.private_key
  cacertfile = google_sql_ssl_cert.querydesk.server_ca_cert
}

# you can setup whatever configuration of users you want
# with this example there is a readonly user that doesn't require reviews and one user that has full access but requires 1 review
resource "querydesk_database_user" "demo_readonly" {
  database_id      = querydesk_database.demo.id
  username         = "readonly"
  password         = random_password.querydesk_db_password.result
  reviews_required = 0
}

resource "querydesk_database_user" "demo_querydesk" {
  database_id      = querydesk_database.demo.id
  username         = google_sql_user.querydesk.name
  password         = random_password.querydesk_db_password.result
  reviews_required = 1
}
