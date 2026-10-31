$ErrorActionPreference = 'Stop'
$pass = 0
$fail = 0

if (Test-Path .env) {
    Get-Content .env | Where-Object { $_ -match '^\s*[^#=]+=.*$' } | ForEach-Object {
        $parts = $_ -split '=', 2
        Set-Variable -Name $parts[0].Trim() -Value $parts[1].Trim() -Scope Script
    }
}

function Test-Check([string]$Name, [scriptblock]$Action) {
    try {
        & $Action | Out-Null
        Write-Host "PASS: $Name" -ForegroundColor Green
        $script:pass++
    } catch {
        Write-Host "FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
        $script:fail++
    }
}

Test-Check 'Web frontend' { Invoke-WebRequest http://localhost:8080/ -UseBasicParsing }
Test-Check 'Web blog' { Invoke-WebRequest http://localhost:8080/blog/ -UseBasicParsing }
Test-Check 'Application /hello' { Invoke-WebRequest http://localhost:8085/hello -UseBasicParsing }
Test-Check 'Application /secure rejects missing token' {
    try { Invoke-WebRequest http://localhost:8085/secure -UseBasicParsing; throw 'Expected HTTP 401' }
    catch { if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw } }
}
$token = (Invoke-RestMethod -Method Post -Uri http://localhost:8081/realms/minicloud/protocol/openid-connect/token -Body @{
    client_id = 'minicloud-app'; username = 'student'; password = 'student123'; grant_type = 'password'
}).access_token
Test-Check 'Application /secure accepts Keycloak token' { if ([string]::IsNullOrWhiteSpace($token)) { throw 'No access token' } }
Test-Check 'Application /secure returns authenticated response' {
    $secure = Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } -Uri http://localhost:8085/secure
    if ($secure.authenticated -ne $true) { throw 'Secure endpoint did not authenticate' }
}
Test-Check 'MariaDB' {
    & docker compose exec -T relational-database-server mariadb "-uroot" "-p$MARIADB_ROOT_PASSWORD" -e 'SHOW DATABASES;'
    if ($LASTEXITCODE -ne 0) { throw "MariaDB command exited with code $LASTEXITCODE" }
}
Test-Check 'Keycloak' { Invoke-WebRequest http://localhost:8081/realms/minicloud -UseBasicParsing }
Test-Check 'MinIO API' { Invoke-WebRequest http://localhost:9000/minio/health/live -UseBasicParsing }
Test-Check 'DNS cloud.local' {
    $dnsOutput = & docker exec minicloud-dns nslookup web-server.cloud.local 127.0.0.1 2>&1
    $dnsText = $dnsOutput -join "`n"
    if ($LASTEXITCODE -ne 0 -or $dnsText -notmatch '172\.28\.0\.11') {
        throw "DNS lookup did not return 172.28.0.11`n$dnsText"
    }
}
Test-Check 'Prometheus' { Invoke-WebRequest http://localhost:9090/-/healthy -UseBasicParsing }
Test-Check 'Node exporter' { Invoke-WebRequest http://localhost:9100/metrics -UseBasicParsing }
Test-Check 'Grafana' { Invoke-WebRequest http://localhost:3000/api/health -UseBasicParsing }
Test-Check 'Reverse proxy' { Invoke-WebRequest http://localhost/ -UseBasicParsing }

if ($fail -eq 0) { Write-Host "RESULT: PASS ($pass checks)" -ForegroundColor Green; exit 0 }
Write-Host "RESULT: FAIL ($pass passed, $fail failed)" -ForegroundColor Red
exit 1
