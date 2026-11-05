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