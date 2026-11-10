#!/usr/bin/env bash
# Run from a complete project checkout on Ubuntu EC2:
# sudo bash setup-ec2.sh [public-ip-or-dns]
# Docker install: https://docs.docker.com/engine/install/ubuntu/
set -Eeuo pipefail
trap 'printf "Setup failed at line %s. Check the error above and docker compose logs.\n" "$LINENO" >&2' ERR

usage() {
    printf 'Usage: sudo bash setup-ec2.sh [public-ip-or-dns]\n'
    printf 'Without an argument, detect the EC2 public IPv4 using IMDSv2.\n'
    printf 'On first setup, enter five service passwords at the hidden prompts.\n'
    printf 'Pulls published images; custom images must already exist on Docker Hub.\n'
    printf 'Optional override: sudo bash setup-ec2.sh ec2-example.compute.amazonaws.com\n'
    printf 'Run from a complete MiniCloud checkout. Existing DB volumes are preserved.\n'
}

detect_public_ipv4() {
    local metadata_url='http://169.254.169.254/latest'
    local metadata_token address octet
    local -a octets
    if ! metadata_token="$(curl --noproxy '*' --fail --silent --connect-timeout 2 --max-time 5 \
        --request PUT --header 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
        "$metadata_url/api/token")" || [[ -z "$metadata_token" ]]; then
        return 1
    fi
    if ! address="$(curl --noproxy '*' --fail --silent --connect-timeout 2 --max-time 5 \
        --header "X-aws-ec2-metadata-token: $metadata_token" \
        "$metadata_url/meta-data/public-ipv4")"; then
        return 1
    fi
    [[ "$address" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "$address"
    for octet in "${octets[@]}"; do
        (( 10#$octet <= 255 )) || return 1
    done
    printf '%s' "$address"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi
if [[ $# -gt 1 ]] || [[ $# -eq 1 && ! "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
    usage >&2
    printf 'Provide a public IPv4 address or DNS hostname, without http://, port or path.\n' >&2
    exit 1
fi
PUBLIC_HOST="${1:-}"
if [[ "$EUID" -ne 0 ]]; then
    printf 'Run with sudo: sudo bash setup-ec2.sh [public-ip-or-dns]\n' >&2
    exit 1
fi
# shellcheck source=/dev/null
source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    printf 'This setup script requires Ubuntu.\n' >&2
    exit 1
fi

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
for required in docker-compose.yml .env.example \
    proxy/nginx.conf \
    web/conf.server-2 web/html/index-server-2.html \
    db/init/001_init.sql db/init/002_studentdb.sql \
    auth/realm/minicloud-realm.json auth/realm/realm_sv001-realm.json \
    monitor/prometheus.yml grafana/provisioning/datasources/prometheus.yml \
    grafana/provisioning/dashboards/dashboard.yml grafana/dashboards/minicloud.json \
    grafana/dashboards/system-health-sv001.json dns/named.conf dns/named.conf.options \
    dns/named.conf.local dns/db.cloud.local; do
    if [[ ! -f "$required" ]]; then
        printf 'Missing %s. Copy or clone the complete project before running setup.\n' "$required" >&2
        exit 1
    fi
done

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl python3

if [[ -z "$PUBLIC_HOST" ]]; then
    if ! PUBLIC_HOST="$(detect_public_ipv4)"; then
        printf 'Cannot detect a public IPv4 from EC2 metadata. Check IMDS access and the instance public IPv4, or pass a public IP/DNS explicitly.\n' >&2
        exit 1
    fi
    printf 'Detected EC2 public IPv4: %s\n' "$PUBLIC_HOST"
else
    printf 'Using supplied public host: %s\n' "$PUBLIC_HOST"
fi

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl --fail --silent --show-error --location \
        https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
docker compose version

# Parse dotenv as data; never source it as shell code or print passwords.
python3 - "$PROJECT_DIR" "$PUBLIC_HOST" <<'PY'
import getpass
import json
import os
import re
import sys
import warnings
from pathlib import Path

root = Path(sys.argv[1])
public_host = sys.argv[2]
env_path = root / ".env"
exists = env_path.exists()
text = env_path.read_text(encoding="utf-8") if exists else (root / ".env.example").read_text(encoding="utf-8")

def get_value(key):
    match = re.search(rf"^{re.escape(key)}=(.*)$", text, flags=re.MULTILINE)
    return match.group(1).strip().strip("\"'") if match else ""

def set_value(key, value):
    global text
    # Double-quoted dotenv handles quotes/backslashes; $$ prevents Compose interpolation.
    line = key + "=" + json.dumps(value.replace("$", "$$"), ensure_ascii=False)
    if re.search(rf"^{re.escape(key)}=.*$", text, flags=re.MULTILINE):
        text = re.sub(rf"^{re.escape(key)}=.*$", lambda match: line, text, flags=re.MULTILINE)
    else:
        text = text.rstrip() + "\n" + line + "\n"

for key in ("MARIADB_DATABASE", "MARIADB_USER", "KEYCLOAK_ADMIN", "MINIO_ROOT_USER", "GRAFANA_ADMIN_USER"):
    value = get_value(key)
    if not value or value.startswith("change_this_"):
        raise SystemExit(f"Set a non-placeholder value for {key} in .env before deploying.")
if get_value("MARIADB_USER") != "minicloud_user":
    raise SystemExit("The seed SQL grants access to minicloud_user. Align MARIADB_USER with the SQL before deploying.")

password_fields = (
    ("MARIADB_ROOT_PASSWORD", "MariaDB root"),
    ("MARIADB_PASSWORD", "MariaDB application user"),
    ("KEYCLOAK_ADMIN_PASSWORD", "Keycloak admin"),
    ("MINIO_ROOT_PASSWORD", "MinIO admin"),
    ("GRAFANA_ADMIN_PASSWORD", "Grafana admin"),
)
pending = [(key, label) for key, label in password_fields
           if not exists or not get_value(key) or get_value(key).startswith("change_this_")]
if pending:
    try:
        # Python reads this program from stdin; passwords must come from the SSH terminal.
        with open("/dev/tty", "w", encoding="utf-8") as terminal, warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            for key, label in pending:
                while True:
                    password = getpass.getpass(f"{label} password (at least 8 characters): ", stream=terminal)
                    if len(password) < 8 or password.startswith("change_this_") or any(ord(char) < 32 or ord(char) == 127 for char in password):
                        print("Use at least 8 characters and no control characters or placeholder password.", file=terminal)
                        continue
                    confirmation = getpass.getpass(f"Confirm {label} password: ", stream=terminal)
                    if password != confirmation:
                        print("Passwords do not match. Try again.", file=terminal)
                        continue
                    set_value(key, password)
                    break
    except (OSError, EOFError, KeyboardInterrupt, getpass.GetPassWarning):
        raise SystemExit("Password entry requires an interactive SSH terminal. Rerun in SSH or prepare a complete .env beforehand; no passwords were saved.")

for key, realm in (("KEYCLOAK_ISSUER", "minicloud"), ("KEYCLOAK_EXTRA_ISSUER", "realm_sv001")):
    line = f"{key}=http://{public_host}:8081/realms/{realm}"
    if re.search(rf"^{key}=.*$", text, flags=re.MULTILINE):
        text = re.sub(rf"^{key}=.*$", lambda match: line, text, flags=re.MULTILINE)
    else:
        text = text.rstrip() + "\n" + line + "\n"

# Restrict permissions before writing secrets.
fd = os.open(env_path, os.O_WRONLY | os.O_CREAT, 0o600)
with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as file:
    os.fchmod(file.fileno(), 0o600)
    file.write(text.rstrip() + "\n")
    file.truncate()
print("Updated .env; existing configured passwords preserved." if exists else "Created .env with your service passwords and public Keycloak issuers.")
PY

if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    chown -- "$SUDO_USER:$(id -gn "$SUDO_USER")" "$PROJECT_DIR/.env"
fi

docker compose config --quiet
if ! docker compose pull; then
    printf 'Image pull failed. Publish both frontend and backend images with tag latest first; use sudo docker login for private repositories.\n' >&2
    exit 1
fi
docker compose up -d --no-build --pull never --wait --wait-timeout 300

# The assignment demo uses HTTP on the public IP, including the admin realm.
# Use the container credentials without another prompt or a persistent CLI token.
printf 'Configuring Keycloak realms for the HTTP demo...\n'
docker compose exec -T authentication-identity-server sh -eu -c '
    config_file="$(mktemp /tmp/minicloud-kcadm.XXXXXX)"
    trap '\''rm -f "$config_file"'\'' EXIT
    /opt/keycloak/bin/kcadm.sh config credentials \
        --config "$config_file" \
        --server http://localhost:8080 \
        --realm master \
        --user "$KC_BOOTSTRAP_ADMIN_USERNAME" \
        --password "$KC_BOOTSTRAP_ADMIN_PASSWORD"
    for realm in master minicloud realm_sv001; do
        /opt/keycloak/bin/kcadm.sh update "realms/$realm" \
            --config "$config_file" -s sslRequired=NONE
        printf "HTTP enabled for realm: %s\n" "$realm"
    done
'

# MariaDB imports init SQL on the first startup of a new data volume.
# This checks the result; it does not reapply seed SQL or reset existing data.
student_count="$(docker compose exec -T relational-database-server sh -c \
    'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb --user=root --database=studentdb --batch --skip-column-names --execute="SELECT COUNT(*) FROM students;"')"
student_count="${student_count//$'\r'/}"
if [[ ! "$student_count" =~ ^[0-9]+$ ]] || (( student_count < 3 )); then
    printf 'Expected at least 3 seed students. Existing volumes do not rerun init SQL.\n' >&2
    exit 1
fi
curl --fail --silent --show-error --retry 10 --retry-delay 2 --retry-connrefused \
    http://127.0.0.1/api/students-db >/dev/null
docker compose ps
printf '\nReady: %s students in studentdb.\n' "$student_count"
printf 'Web: http://%s/\nStudent API: http://%s/api/students-db\n' "$PUBLIC_HOST" "$PUBLIC_HOST"
printf 'Keycloak: http://%s:8081/\nGrafana: http://%s:3000/\n' "$PUBLIC_HOST" "$PUBLIC_HOST"
printf 'MinIO Console: http://%s:9001/\nCredentials: %s/.env\n' "$PUBLIC_HOST" "$PROJECT_DIR"
