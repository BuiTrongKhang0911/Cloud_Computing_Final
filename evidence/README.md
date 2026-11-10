# Evidence index

Screenshots are grouped by the baseline demo area. Filenames use numeric prefixes so they stay in presentation order.

| Folder | Screenshot | What it demonstrates |
| --- | --- | --- |
| `01-containers/` | `01-compose-all-services-healthy.png` | Compose services are running and healthy. |
| `01-containers/` | `02-cloud-net-ping-all-services-pass.png` | All ten Compose service names resolve and respond to ICMP ping from a temporary container on `cloud-net`. |
| `02-web/` | `01-home-page.png`, `02-blog-page.png` | Nginx serves the homepage and blog. |
| `03-application-database/` | `01-api-direct-and-through-proxy.png` | `/hello` responds directly and through the proxy. |
| `03-application-database/` | `02-app-reads-database-services.png` | Flask reads seeded service rows from MariaDB. |
| `04-authentication/` | `01-keycloak-admin-console.png` | Keycloak admin console is accessible. |
| `05-proxy/` | `01-auth-route-redirects-to-keycloak.png` | `/auth/` routes to Keycloak and returns a redirect. |
| `06-object-storage/` | `01-minio-upload-complete.png` | MinIO bucket contains an uploaded object. |
| `07-dns/` | `01-web-service-name-resolves.png` | Bind9 resolves the web service name to its configured IP. |
| `08-monitoring/` | `01-prometheus-targets-up.png` | Prometheus scrape targets are UP. |
| `08-monitoring/` | `02-grafana-overview-dashboard.png` | Grafana displays CPU, memory, and network metrics. |

Existing text logs and command output files remain at the root of this folder. Before adding evidence to a public report or repository, review screenshots and logs for credentials, tokens, or personal information.

## Stage 3 extension evidence

| Area | Suggested evidence |
| --- | --- |
| `09-blog-3-posts/` | `01-blog-index-page.png` shows the redesigned journal landing page; `02`–`04` show the cloud, containers, and metrics article pages with illustrations. |
| `10-api-student-json/` | `01-api-student-five-records.png`: `/api/student` returns five records. |
| `11-database-studentdb/` | `01-studentdb-seed-and-api-response.png`: studentdb migration and `/api/students-db` returns three records. Add a DB query screenshot if available. |
| `12-keycloak-realm/` | `01-secure-endpoint-authenticated.png`: successful `/secure` response. `02` shows the student realm, `03` the `flask-app` client, and `04` the two student users. The first screenshot still exposes a demo password; redact it before committing/sharing, and never expose an access token. |
| `13-minio-profile-documents/` | `01` shows the bucket list; `02` shows `images.jpg` in `profile-pics`; `03` shows `Report.pdf` in `documents`. Both target buckets are private in the screenshots. |
| `14-dns-extension/` | `01-app-minio-keycloak-resolve.png`: `app-backend`, `minio`, and `keycloak` lookup results. |
| `15-prometheus-web-target/` | `01-web-target-up.png` shows Prometheus target `web` at `http://web-frontend-server/metrics` in UP state. |
| `16-grafana-system-health/` | `01-student-system-health-dashboard.png` shows the System Health of SV001 dashboard with CPU, memory, and network panels populated. |
| `17-proxy-student-route/` | `01-student-route-through-proxy.png` shows `curl http://localhost/student/` returning the five student records through the gateway. |
| `18-load-balancing/` | `01-round-robin-two-web-instances.png`: responses alternate between `web-frontend-server` and `web-frontend-server-2`. |
| `19-docker-hub/` | `01-docker-hub-frontend-images.png` shows both frontend image repositories in the Docker Hub account. |
