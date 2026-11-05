# Warehouse Collecto central server

ASP.NET Core 10 API foundation for shared accounts and receipt synchronization.

## Hosting
Run on an always-on Windows shop server reachable by all distributor devices on the shop LAN. Configure a static LAN address or DHCP reservation, firewall access to TCP 5080, persistent database storage, and tested backups. For access outside the shop LAN, deploy behind HTTPS on a trusted host or use a properly configured VPN. Do not expose the plain HTTP listener directly to the public internet.

Required environment variables:
- JWT_SECRET: cryptographically random secret, at least 32 UTF-8 bytes.
- BOOTSTRAP_KEY: one-time secret used to create the first server administrator.

Create the first administrator with POST /api/auth/bootstrap. This endpoint refuses further bootstrap after the first user exists. Sign in through POST /api/auth/login. Administrators manage shared users through /api/admin/users. Authenticated devices upload receipts through POST /api/sync/receipts.

## Integration status
This is the first central API foundation. Flutter still uses local SQLite for sign-in and data entry until its client networking, secure token storage, customer download, receipt upload/retry, and conflict handling are connected and tested. Existing device-local accounts are not automatically copied to the server. A server deployment and a reviewed import procedure are required before cross-device sign-in is operational.

## Production requirements
Use HTTPS outside a trusted LAN, keep secrets out of source control, restrict server access, back up and test restore, and use reviewed EF Core migrations for schema changes. This initial prototype uses EnsureCreated and is not production-ready.

## Build and run on the shop Windows PC

A self-contained Windows x64 package is produced by the **Publish Windows server** GitHub Actions workflow. Download its `warehouse-collecto-windows-server` artifact and extract it into a permanent folder on the shop PC.

1. Open PowerShell in that folder.
2. Generate a strong JWT secret and a one-time bootstrap key (keep both private):
   `$env:JWT_SECRET = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))`
   `$env:BOOTSTRAP_KEY = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))`
3. Start `.WarehouseCollecto.Api.exe` from that folder. Keep the window/process running.
4. Find the PC's private LAN IPv4 address using `ipconfig`. Allow TCP 5080 only on the Windows Private network profile.
5. On the administrator phone, configure the app with `http://SERVER-LAN-IP:5080`, enter the one-time bootstrap key, and create the first central administrator. Other phones enter the same URL and sign in with accounts created by that administrator.
6. After the first administrator is created, the bootstrap key can be discarded. Keep JWT_SECRET unchanged across restarts or all active tokens will become invalid.

Example private-network firewall rule (run PowerShell as Administrator):
`New-NetFirewallRule -DisplayName "Warehouse Collecto LAN API" -Direction Inbound -Protocol TCP -LocalPort 5080 -Action Allow -Profile Private`

Do not expose port 5080 directly to the public internet. For remote access, use a VPN or a trusted HTTPS reverse proxy. The app allows plain HTTP only for private LAN IP addresses. Back up `warehouse-collecto.db` regularly and test restoration; stop the server before making a simple file copy backup.

The server build is a foundation, not a completed production deployment. Before real-money use, configure a managed Windows service, backup rotation, monitoring, TLS/VPN access where needed, and reviewed EF Core migrations. The server currently uses SQLite with `EnsureCreated`; schema evolution still needs a production migration plan.
