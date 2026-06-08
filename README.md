# Terminal King Terminal

> **Secure, browser-based SSH terminal — open source.**

**Terminal King Terminal** is a production-ready, white-labeled browser-based SSH
terminal built on [WebSSH2](https://github.com/billchurch/webssh2) (MIT licensed).
Deployed at [terminalking.com/terminal](https://terminalking.com/terminal/).

**Repository:** [github.com/rasrobo/terminal-king-terminal](https://github.com/rasrobo/terminal-king-terminal)

Built and maintained by **[SideQuest Studios](https://sidequeststudios.xyz)**.

## Architecture

```
terminalking.com ─── existing nginx-proxy + acme-companion (HTTPS)
│
├── /           → terminalking-ghost (Ghost blog, UNAFFECTED)
│
└── /terminal/  → terminal-king-terminal (billchurch/webssh2, internal only)
                    ├── HTTP Basic Auth (nginx layer, BEFORE app)
                    ├── Trusted proxy headers (X-Authenticated-User)
                    ├── WebSocket upgrade (for xterm.js terminal I/O)
                    ├── Branded UI (Terminal King Terminal)
                    ├── IP allowlist (backend-controlled targets)
                    └── Non-root SSH sessions only
```

## File Tree

```
terminal-king-terminal/
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
│   ├── terminal-king-terminal.css  # Custom styles
│   └── terminal-king-terminal-icon.svg  # Favicon
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
git clone https://github.com/rasrobo/terminal-king-terminal.git
cd terminal-king-terminal
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
sudo cp /var/www/terminalking.com/terminal-king-terminal/.htpasswd "$VHOST_PATH/htpasswd/terminalking.htpasswd"
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
| `TKT_SSH_HOST` | Target SSH server IP/hostname | `127.0.0.1` |
| `TKT_SSH_PORT` | Target SSH port | `22` |
| `TKT_SSH_USERNAME` | Non-root SSH account | `tktoperator` |
| `TKT_ALLOWED_IPS` | IP allowlist (CIDR, comma-separated) | `127.0.0.1/32` |
| `TKT_FORBIDDEN_IPS` | Explicitly blocked IPs | `0.0.0.0/0` |
| `TKT_AUTH_USER` | Basic Auth username | `admin` |
| `TKT_AUTH_PASSWORD` | Basic Auth password | *(strong random)* |

## Operations

View logs:

```bash
docker logs -f terminal-king-terminal
```

Restart:

```bash
docker compose restart terminal-king-terminal
```

Update WebSSH2 image:

```bash
docker compose pull && docker compose up -d
bash scripts/verify.sh
```

Rollback (stops Terminal King Terminal, Ghost blog unaffected):

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
4. Branding says "Terminal King Terminal"
5. Security headers present (HSTS, CSP, X-Frame-Options)
6. TLS certificate valid
7. Container hardening (read-only fs, no-new-privileges, internal network)

## Security Notes

- **Root SSH login is blocked** — uses a non-root service account
- **No public connection form** — targets are backend-controlled via `.env`
- **IP allowlisting** — only approved target IPs
- **Auth before app** — nginx validates credentials before any request reaches the app
- **`.env` and `.htpasswd` are gitignored**
- **Read-only container** — only `/tmp` is writable

See [HARDENING.md](./HARDENING.md) for the full checklist including target SSH server hardening.

## Upstream Customizations

This project is a security-hardened, white-labeled deployment of
[WebSSH2](https://github.com/billchurch/webssh2). Key customizations:

- Default connection form (host/user/password inputs) is **not used** — targets configured server-side
- Upstream `index.html` replaced at volume-mount time with branded version
- WebSocket transport configured through nginx proxy
- App's built-in auth bypassed in favor of nginx Basic Auth via trusted headers
- No modifications to upstream WebSSH2 Node.js code needed

## Credits & License

- **Upstream:** [WebSSH2](https://github.com/billchurch/webssh2) by Bill Church — [MIT License](https://github.com/billchurch/webssh2/blob/main/LICENSE)
- **Security hardening, branding, deployment:** [SideQuest Studios](https://sidequeststudios.xyz)
- **License:** [MIT](./LICENSE) — same as upstream

This project is open source. Contributions welcome at
[github.com/rasrobo/terminal-king-terminal](https://github.com/rasrobo/terminal-king-terminal).
