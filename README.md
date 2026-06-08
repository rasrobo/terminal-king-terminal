# QuestShell — Secure Browser Terminal

**QuestShell** is a production-ready, white-labeled browser-based SSH terminal.
It wraps [WebSSH2](https://github.com/billchurch/webssh2) (MIT licensed) in
a secure, authenticated, branded experience deployed at
[terminalking.com/terminal](https://terminalking.com/terminal/).

Built and maintained by **[SideQuest Studios](https://sidequeststudios.xyz)**.

## Architecture

```
terminalking.com ─── existing nginx-proxy + acme-companion (HTTPS)
│
├── /           → terminalking-ghost (Ghost blog, UNAFFECTED)
│
└── /terminal/  → quest-shell (billchurch/webssh2, internal only)
                    ├── HTTP Basic Auth (nginx layer, BEFORE app)
                    ├── Trusted proxy headers (X-Authenticated-User)
                    ├── WebSocket upgrade (for xterm.js terminal I/O)
                    ├── Branded UI (QuestShell, not WebSSH2)
                    ├── IP allowlist (backend-controlled targets)
                    └── Non-root SSH sessions only
```

## File Tree

```
quest-shell/
├── docker-compose.yml              # Main deployment manifest
├── .env                            # Secrets (gitignored)
├── .env.example                    # Safe template with placeholders
├── .gitignore
├── README.md                       # This file
├── HARDENING.md                    # Full security checklist
├── LICENSE                         # MIT
│
├── nginx/
│   ├── vhost-terminalking.conf     # nginx vhost (auth, WS, headers)
│   ├── htpasswd.example            # Placeholder htpasswd
│   └── README.md                   # nginx-proxy integration guide
│
├── branding/
│   ├── index.html                  # Branded landing page
│   ├── quest-shell.css             # Custom styles
│   └── quest-shell-icon.svg        # Favicon
│
└── scripts/
    ├── setup.sh                    # One-time server setup
    ├── deploy.sh                   # Deploy / update
    ├── verify.sh                   # Security verification suite
    └── gen-passwords.sh            # Password generator
```

## Prerequisites

- Docker + Docker Compose on the server
- Existing `nginx-proxy` + `acme-companion` stack running
- Docker network `nginx-proxy` exists
- DNS: `terminalking.com` A record points to this server

## Quick Deploy

Step 1 — clone and run setup:

```bash
cd /var/www/terminalking.com/
git clone <repo-url> quest-shell
cd quest-shell
bash scripts/setup.sh
```

Step 2 — edit your `.env`:

```bash
nano .env
```

Step 3 — place the nginx vhost config and htpasswd into the nginx-proxy volume:

```bash
VHOST_VOL=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/vhost.d"}}{{.Name}}{{end}}{{end}}')
VHOST_PATH=$(docker volume inspect "$VHOST_VOL" --format '{{.Mountpoint}}')
sudo cp nginx/vhost-terminalking.conf "$VHOST_PATH/terminalking.com"
sudo mkdir -p "$VHOST_PATH/htpasswd"
sudo cp /var/www/terminalking.com/quest-shell/.htpasswd "$VHOST_PATH/htpasswd/terminalking.htpasswd"
docker exec nginx-proxy nginx -s reload
```

Step 4 — deploy:

```bash
bash scripts/deploy.sh
```

Step 5 — verify:

```bash
bash scripts/verify.sh
```

## Configuration

| Variable | Purpose | Example |
|---|---|---|
| `QS_SSH_HOST` | Target SSH server IP/hostname | `127.0.0.1` |
| `QS_SSH_PORT` | Target SSH port | `22` |
| `QS_SSH_USERNAME` | Non-root SSH account | `qsoperator` |
| `QS_ALLOWED_IPS` | IP allowlist (CIDR, comma-separated) | `127.0.0.1/32` |
| `QS_FORBIDDEN_IPS` | Explicitly blocked IPs | `0.0.0.0/0` |
| `QS_AUTH_USER` | Basic Auth username | `admin` |
| `QS_AUTH_PASSWORD` | Basic Auth password | *(strong random)* |

## Operations

View logs:

```bash
docker logs -f quest-shell
```

Restart:

```bash
docker compose restart quest-shell
```

Update WebSSH2 image:

```bash
docker compose pull && docker compose up -d
bash scripts/verify.sh
```

Rollback (stops QuestShell, Ghost blog unaffected):

```bash
bash scripts/deploy.sh --rollback
```

Add users:

```bash
htpasswd -bnBC 14 "newuser" "theirpassword"
# Then copy into the nginx-proxy vhost volume and reload
```

## Verification

```bash
bash scripts/verify.sh
```

Checks:
1. Ghost blog still functional
2. Unauthenticated `/terminal/` returns 401
3. Authenticated `/terminal/` returns 200
4. Branding says "QuestShell", not "WebSSH2"
5. Security headers present (HSTS, CSP, X-Frame-Options)
6. TLS certificate valid
7. Container hardening (read-only fs, no-new-privileges, internal network)

## Security Notes

- **Root SSH login is blocked** — QuestShell uses a non-root service account
- **No public connection form** — targets are backend-controlled via `.env`
- **IP allowlisting** — only approved target IPs
- **Auth before app** — nginx validates credentials before any request reaches WebSSH2
- **`.env` and `.htpasswd` are gitignored**
- **Read-only container** — only `/tmp` is writable

See [HARDENING.md](./HARDENING.md) for the full checklist including target SSH server hardening.

## WebSSH2 Customizations

- Default connection form (host/user/password inputs) is **not used** — targets configured server-side
- Upstream `index.html` replaced at volume-mount time with branded version
- WebSocket transport configured through nginx proxy
- App's built-in auth bypassed in favor of nginx Basic Auth via trusted headers
- No modifications to upstream WebSSH2 Node.js code needed

## Credits

- Upstream: [WebSSH2](https://github.com/billchurch/webssh2) by Bill Church (MIT License)
- Branding, security hardening, deployment: [SideQuest Studios](https://sidequeststudios.xyz)
