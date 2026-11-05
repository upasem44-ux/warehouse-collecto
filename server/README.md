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

**Important transport limitation:** the current shop-LAN setup uses plain HTTP. That means traffic (including bearer tokens and customer/receipt data) is not encrypted between phones and the server. The app restricts HTTP configuration to private IPv4 addresses, but that is not a substitute for TLS and does not stop an attacker already on the same Wi-Fi/LAN from observing or modifying traffic. Treat this as an isolated-LAN pilot configuration only. For production or any untrusted network, deploy HTTPS with a certificate trusted by the Android devices, or use a properly configured VPN. Never expose port 5080 directly to the public internet.

## Minimum secure shop-network checklist

Before connecting any real phone:
- Update Windows fully and use a dedicated Windows account for the API; do not run the server as an administrator.
- Set the shop router to WPA2-AES or WPA3 with a unique strong Wi-Fi password. Disable WPS and change the router's default administrator password.
- Put the server and collection phones on a private shop network. Do not use guest Wi-Fi, public Wi-Fi, or a network shared with customers/visitors.
- Do not configure router port-forwarding, DMZ, UPnP exposure, or remote administration for port 5080.
- Keep the Windows firewall rule limited to the Private profile and TCP 5080. Do not create a broad "allow all" rule. If practical, restrict the rule further to the shop LAN subnet.
- Use a unique administrator username and a long, unique password. Create separate distributor accounts; never share one account between people. Deactivate accounts immediately when access is no longer needed.
- The API applies per-IP rate limits to login and bootstrap, validates the one-time bootstrap key in constant time, and adds no-store/security response headers. These are defense-in-depth controls, not complete protection.
- Keep the Windows host physically secured and prevent unauthorized access to the server folder and SQLite database file.
- Keep `JWT_SECRET` private and unchanged. Do not paste it, `BOOTSTRAP_KEY`, passwords, or access tokens into chats, screenshots, GitHub issues, or source files. Do not commit secrets to Git.
- After bootstrap, remove the bootstrap key from the process environment and do not reuse it. If it is ever exposed, treat the setup as compromised and plan a controlled re-bootstrap/recovery.
- Keep a written list of authorized devices/users and periodically review active accounts.

## Backup and recovery precautions

The server database is a financial record. Until automated, verified backup/restore is implemented:
1. Stop the API cleanly before making a file-copy backup of `warehouse-collecto.db`; do not rely on copying a live SQLite database file while writes are occurring.
2. Copy the database to a separate encrypted drive or protected backup location. Keep at least one backup disconnected from the server.
3. Label backups with date/time and restrict access to the administrator only.
4. Test restoring a copy into a separate test folder and verify customer balances and receipt counts before considering the backup usable.
5. Never overwrite the live database during a restore test.

A backup that has not been restored and checked is not a proven backup.

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
