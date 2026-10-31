# Nhom16miniclouddemo - MiniCloud

This project simulates nine cloud infrastructure roles as independent Docker
Compose services on the `cloud-net` network. It is intended for local Docker
Desktop on Windows and for Ubuntu EC2.

## Quick start

1. Install Docker Desktop with Compose v2.
2. Copy `.env.example` to `.env` and replace every development password.
3. Build and start:

```powershell
docker compose build
docker compose up -d
docker compose ps
```

If startup reports that host port `3306` is already in use, identify the
process with `Get-NetTCPConnection -LocalPort 3306 -State Listen` in
PowerShell. Stop the local MySQL service intentionally, then retry
`docker compose up -d`; the assignment mapping keeps MariaDB at host port
`3306`. Do not stop an unknown process.

The local `.env` is intentionally excluded from version control. Never commit
AWS keys, private keys, or production passwords.

The object-storage service uses `coollabsio/minio:latest`, a publicly pullable
MinIO-compatible community image. The former `minio/minio:latest` reference is
no longer anonymously pullable in the current registry environment. For a
production system, pin and approve an internally mirrored image or use an
authenticated vendor image.

## Service endpoints

| Role | Service/container | Endpoint |
|---|---|---|
| Web | `web-frontend-server` / `minicloud-web` | http://localhost:8080 |
| Application | `application-backend-server` / `minicloud-app` | http://localhost:8085/hello |
| Database | `relational-database-server` / `minicloud-db` | localhost:3306 |
| Authentication | `authentication-identity-server` / `minicloud-keycloak` | http://localhost:8081 |
| Object storage | `object-storage-server` / `minicloud-minio` | API 9000, Console 9001 |
| DNS | `internal-dns-server` / `minicloud-dns` | TCP/UDP localhost:1053 |
| Monitoring | `monitoring-prometheus-server` / `minicloud-prometheus` | http://localhost:9090 |
| Node metrics | `node-exporter` / `minicloud-node-exporter` | http://localhost:9100/metrics |
| Dashboard | `monitoring-grafana-dashboard-server` / `minicloud-grafana` | http://localhost:3000 |
| Gateway | `api-gateway-proxy-server` / `minicloud-proxy` | http://localhost:80 |

The gateway routes `/api/web/` and `/api/app/` to the corresponding upstreams
and strips the `/api/web/` or `/api/app/` prefix.

## Required tests

PowerShell:

```powershell
$env:MARIADB_ROOT_PASSWORD = (Get-Content .env | Select-String 'MARIADB_ROOT_PASSWORD=').ToString().Split('=',2)[1]
.\test_all.ps1
```

Linux/macOS:

```bash
set -a; . ./.env; set +a
chmod +x test_all.sh
./test_all.sh
```

Database inspection:

```powershell
docker exec -it minicloud-db mariadb -uroot -p -e "SHOW DATABASES;"
```

Keycloak has the imported realm `minicloud` and demo user `student`. For local
testing only, obtain a token with:

```powershell
curl.exe -s -X POST http://localhost:8081/realms/minicloud/protocol/openid-connect/token ` 
  -d "client_id=minicloud-app" -d "username=student" -d "password=student123" `
  -d "grant_type=password"
```

Use the returned access token with `curl.exe -H "Authorization: Bearer TOKEN"`
against `http://localhost:8085/secure`. Change the demo password before any
shared deployment.

## AWS EC2 deployment

Launch an Ubuntu EC2 instance, create an SSH key pair, and allow only the
ports needed for the demonstration in its Security Group: TCP 22 from the
student IP, TCP 80/8080/8085/8081/9000/9001/9090/3000 as needed, and UDP/TCP
1053 only when DNS must be queried externally. Prefer restricting all
application ports to the student IP or VPN.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
git clone <repository-url> Nhom16miniclouddemo
cd Nhom16miniclouddemo
cp .env.example .env
nano .env
docker compose build
docker compose up -d
docker compose ps
```

Use the EC2 public IPv4 address in browser and curl commands. Record actual
instance ID, region, public IP, Security Group rules, timestamps, and command
outputs under `evidence/`; do not invent them in the report.

## Docker Hub

The custom frontend image is tagged `wasabi4816/myminicloud-web:latest`.
After logging in and testing locally:

```powershell
docker login
docker push wasabi4816/myminicloud-web:latest
```

## Deliverables and known user actions

The report is generated from verified local evidence. The student must still
provide the missing MSSN/class data, take screenshots, create an EC2 instance,
configure its Security Group, push the image to Docker Hub, and add the real
video link. Passwords in this development workspace are placeholders and must
be rotated.
