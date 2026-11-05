$ErrorActionPreference = "Stop"
if (-not $env:JWT_SECRET) {
  $secure = Read-Host "Enter the persistent JWT_SECRET" -AsSecureString
  $env:JWT_SECRET = [System.Net.NetworkCredential]::new("", $secure).Password
}
if (-not $env:BOOTSTRAP_KEY) {
  $secure = Read-Host "Enter the one-time BOOTSTRAP_KEY (leave blank after bootstrap)" -AsSecureString
  $env:BOOTSTRAP_KEY = [System.Net.NetworkCredential]::new("", $secure).Password
}
if ([string]::IsNullOrWhiteSpace($env:JWT_SECRET) -or [Text.Encoding]::UTF8.GetByteCount($env:JWT_SECRET) -lt 32) {
  throw "JWT_SECRET must contain at least 32 UTF-8 bytes."
}
.WarehouseCollecto.Api.exe
