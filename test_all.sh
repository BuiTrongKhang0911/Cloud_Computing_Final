#!/usr/bin/env bash
set -u
PASS=0
FAIL=0

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

check() {
  name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL: %s\n' "$name"
    FAIL=$((FAIL + 1))
  fi
}

check "Web frontend" curl -fsS http://localhost:8080/
check "Web blog" curl -fsS http://localhost:8080/blog/
check "Application /hello" curl -fsS http://localhost:8085/hello
check "Application /secure rejects missing token" sh -c '! curl -fsS http://localhost:8085/secure'
TOKEN=$(curl -fsS -X POST http://localhost:8081/realms/minicloud/protocol/openid-connect/token \
  -d 'client_id=minicloud-app' -d 'username=student' -d 'password=student123' \
  -d 'grant_type=password' 2>/dev/null | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
check "Application /secure accepts Keycloak token" test -n "$TOKEN"
check "Application /secure returns authenticated response" sh -c 'curl -fsS -H "Authorization: Bearer '"$TOKEN"'" http://localhost:8085/secure | grep -q "\"authenticated\":true"'
check "MariaDB" docker compose exec -T relational-database-server mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -e 'SHOW DATABASES;'
check "Keycloak" curl -fsS http://localhost:8081/realms/minicloud
check "MinIO API" curl -fsS http://localhost:9000/minio/health/live
check "DNS cloud.local" sh -c 'docker exec minicloud-dns nslookup web-server.cloud.local 127.0.0.1 | grep -q "172.28.0.11"'
check "Prometheus" curl -fsS http://localhost:9090/-/healthy
check "Node exporter" curl -fsS http://localhost:9100/metrics
check "Grafana" curl -fsS http://localhost:3000/api/health
check "Reverse proxy" curl -fsS http://localhost/

if [ "$FAIL" -eq 0 ]; then
  printf 'RESULT: PASS (%s checks)\n' "$PASS"
  exit 0
fi
printf 'RESULT: FAIL (%s passed, %s failed)\n' "$PASS" "$FAIL"
exit 1
