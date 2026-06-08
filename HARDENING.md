# Terminal King Terminal — Security Hardening Checklist

## Container Hardening

- [x] **Read-only root filesystem** — `read_only: true` in compose
- [x] **No new privileges** — `security_opt: no-new-privileges:true`
- [x] **Capability dropping** — `cap_drop: ALL`, only `NET_BIND_SERVICE` and `NET_RAW` added back
- [x] **Resource limits** — CPU 1.0, Memory 256M max
- [x] **Restart policy** — `unless-stopped` (not `always`, prevents boot loops)
- [x] **Health check** — HTTP liveness probe every 30s
- [x] **Log rotation** — max 10MB × 3 files
- [x] **Rolling tag** — uses `latest` — pin to a digest in production

## Network Hardening

- [x] **No published ports** — container only exposed on internal + proxy networks
- [x] **Internal network** — `terminal-king-terminal-internal` is `internal: true` (no direct external access)
- [x] **Shared proxy network** — only talks to nginx-proxy via `nginx-proxy` external network
- [x] **No inter-container leaks** — Ghost blog is on a separate network

## Authentication

- [x] **HTTP Basic Auth** — nginx gates ALL `/terminal/*` requests before they reach the app
- [x] **Trusted headers only** — `X-Authenticated-User` set by nginx (not by clients)
- [x] **Auth header stripping** — `Authorization` header cleared before proxying to app
- [x] **Rate limiting** — 5 req/s per IP with burst of 10
- [x] **bcrypt htpasswd** — cost factor 14 via `htpasswd -B`

## SSH Security (Terminal King Terminal → Target Server)

- [x] **Root login blocked** — app configured to use a non-root account
- [x] **IP allowlist** — `TKT_ALLOWED_IPS` restricts which hosts can be targeted
- [ ] **`PermitRootLogin no`** — must be set on the **target SSH server**
- [ ] **Key-based auth preferred** — SSH keys over passwords
- [ ] **Non-root sudo user** — create a dedicated `tktoperator` account
- [ ] **Locked root password** — `passwd -l root` on target
- [ ] **SSH config hardening** — see below

## TLS / HTTPS

- [x] **TLS termination at proxy** — handled by nginx-proxy + acme-companion (Let's Encrypt)
- [x] **HSTS** — `max-age=63072000; includeSubDomains; preload`
- [x] **HTTPS redirect** — handled by nginx-proxy (HTTP→HTTPS)
- [ ] **Cert renewal** — verify acme-companion is running and renewing

## Security Headers

- [x] `X-Frame-Options: DENY` — no iframe embedding
- [x] `X-Content-Type-Options: nosniff`
- [x] `Content-Security-Policy` — strict, allows WebSocket upgrades
- [x] `Referrer-Policy: no-referrer`
- [x] `Permissions-Policy` — fullscreen only
- [x] `X-Powered-By` — hidden
- [x] `Server` — hidden from response

## Information Disclosure

- [x] **No secrets in `.env.example`** — safe placeholders only
- [x] **`.env` gitignored** — not in repo
- [x] **`.htpasswd` gitignored** — not in repo
- [x] **No version strings** exposed to clients
- [x] **`robots: noindex, nofollow`** — search engines blocked
- [x] **No default connection form** — backend-controlled targets only

## WebSocket Security

- [x] **WSS only** — `wss://` enforced via HTTPS
- [x] **Path-scoped** — `/terminal/socket.io` not at root
- [x] **CSP allows WS** — `connect-src` includes `wss://terminalking.com`

---

## Target SSH Server Hardening (MANDATORY)

The server that Terminal King Terminal connects **to** must be hardened:

```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers tktoperator
Protocol 2
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
```

```bash
# Create the non-root operator account
sudo adduser --disabled-password --gecos "" tktoperator
sudo usermod -aG sudo tktoperator

# Deploy SSH key
sudo mkdir -p /home/tktoperator/.ssh
sudo cp ~/.ssh/authorized_keys /home/tktoperator/.ssh/
sudo chown -R tktoperator:tktoperator /home/tktoperator/.ssh
sudo chmod 700 /home/tktoperator/.ssh
sudo chmod 600 /home/tktoperator/.ssh/authorized_keys

# Lock root
sudo passwd -l root

# Restart SSH
sudo systemctl restart sshd
```

## Ongoing Maintenance

- [ ] Pin the WebSSH2 image to a SHA digest instead of `latest`
- [ ] Subscribe to WebSSH2 security advisories
- [ ] Rotate htpasswd passwords every 90 days
- [ ] Review Terminal King Terminal access logs monthly: `docker logs terminal-king-terminal`
- [ ] Monitor nginx-proxy access logs for brute-force attempts
- [ ] Keep Docker and the host OS updated
