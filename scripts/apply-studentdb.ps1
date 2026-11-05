$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'
$sqlFile = Join-Path $projectRoot 'relational-database-server/init/02-studentdb.sql'

if (-not (Test-Path -LiteralPath $envFile)) {
    throw 'Missing .env. Copy .env.example to .env and configure the database credentials first.'
}

$rootPasswordLine = Get-Content -LiteralPath $envFile | Where-Object { $_ -match '^MARIADB_ROOT_PASSWORD=' } | Select-Object -First 1
if (-not $rootPasswordLine) {
    throw 'MARIADB_ROOT_PASSWORD was not found in .env.'
}

$env:MYSQL_PWD = $rootPasswordLine.Substring('MARIADB_ROOT_PASSWORD='.Length)
try {
    Get-Content -LiteralPath $sqlFile -Raw | docker compose --project-directory $projectRoot exec -T -e MYSQL_PWD relational-database-server mariadb -uroot
    if ($LASTEXITCODE -ne 0) {
        throw "MariaDB migration failed with exit code $LASTEXITCODE."
    }
    Write-Host 'studentdb schema and sample rows are ready.' -ForegroundColor Green
}
finally {
    Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
}
