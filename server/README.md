# Dawacom / Warehouse Collecto

## Current implementation

This repository contains:
- A Flutter Android collection app with local SQLite storage for customer data and receipts.
- Central authentication and user administration through the ASP.NET Core API when a server URL is configured.
- Secure token storage on Android and a time-limited cached offline session.
- Customer download/import and receipt synchronization using per-operation IDs to make retries idempotent.
- A self-contained Windows x64 package for hosting the central API.

Local receipt entry remains available offline. Receipts are queued locally and uploaded when the device can reach the central server. The central API uses .NET 10 and SQLite.

## Build artifacts

GitHub Actions creates:
- **Android APK:** workflow named `Build Android APK`; download the `warehouse-collector-app` artifact.
- **Windows server:** workflow named `Publish Windows server`; download the `warehouse-collecto-windows-server` artifact.

Artifacts are available from the repository's Actions page:
https://github.com/upasem44-ux/warehouse-collecto/actions

Use artifacts produced from the same `main` commit when preparing a release. The workflow artifacts expire after the retention period shown by GitHub.

## Deploying the central server on the shop PC

The server must run on an always-on Windows x64 PC reachable by all collection phones over the shop's private LAN.

Required environment variables:
- `JWT_SECRET`: cryptographically random secret, at least 32 UTF-8 bytes. Keep it unchanged across restarts.
- `BOOTSTRAP_KEY`: one-time secret used only to create the first administrator.

1. Download and extract the `warehouse-collecto-windows-server` artifact into a permanent folder on the shop PC.
2. Open PowerShell in that folder.
3. Generate secrets and keep them private:
   ```powershell
   $env:JWT_SECRET = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(48))
   $env:BOOTSTRAP_KEY = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
   ```
4. Start `WarehouseCollecto.Api.exe` and keep the process running. The default listener is `http://0.0.0.0:5080`.
5. Find the PC's private IPv4 address using `ipconfig`. Allow inbound TCP 5080 only on the Windows **Private** network profile:
   ```powershell
   New-NetFirewallRule -DisplayName "Warehouse Collecto LAN API" -Direction Inbound -Protocol TCP -LocalPort 5080 -Action Allow -Profile Private
   ```
6. On the administrator phone, configure the app with `http://SERVER-LAN-IP:5080`, then use the one-time bootstrap key to create the first central administrator.
7. Create each distributor account from the administrator account. Configure the same server URL on each phone and sign in.
8. After successful bootstrap, discard the bootstrap key. Keep `JWT_SECRET` private and unchanged.

The app only permits plain HTTP for private IPv4 LAN addresses. Use HTTPS or a properly configured VPN for access outside the shop LAN. Never expose port 5080 directly to the public internet.

## Data safety and release limitations

**This is not yet certified for production financial use.** Passing CI tests and producing APK/server artifacts do not replace testing on the actual shop network and devices.

Before recording real collections:
- Test two or more phones against the same server, including offline entry, reconnect, duplicate retry, and conflicting transfer references.
- Verify customer opening balances and receipt totals against the source accounting system.
- The Flutter local SQLite schema currently stores monetary values using SQLite `REAL` and Dart `double`. The central API uses .NET `decimal`, but the local storage path still needs an exact-money migration (for example integer minor units) and migration tests before it can be treated as financially exact.
- Confirm customer visibility and distributor assignment rules with the business owner; the current central customer endpoint returns the shared customer list to authenticated users.
- Set up a managed Windows service, restricted firewall rules, monitoring, scheduled database backups, and a tested restore procedure. The server currently uses SQLite `EnsureCreated`; a reviewed schema migration strategy is still required.
- Test the recovery procedure using a separate copy of the database before relying on backups.
- LiveExPro import/synchronization is not implemented until its supported interface and data mapping are provided and tested.

Do not use the system as the sole financial record until these checks are completed and signed off.
