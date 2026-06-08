# Terminal King Terminal — Agent Guide

## What This Is

Terminal King Terminal is a white-labeled, security-hardened deployment of WebSSH2
(browser-based SSH terminal) for SideQuest Studios. It runs at
`terminalking.com/terminal/` alongside the existing Ghost blog.

## Key Constraints

1. **Never break the Ghost blog** at `terminalking.com/` — Terminal King Terminal only
   serves from `/terminal/` path
2. **Never expose unauthenticated terminal access** — all `/terminal/*`
   routes require HTTP Basic Auth at the nginx layer
3. **Never allow root SSH** — the app uses a non-root service account
4. **Never store secrets in the repo** — `.env` and `.htpasswd` are gitignored
5. **Never trust client-supplied headers** — `X-Authenticated-User` is only
   set by nginx after auth validation

## File Conventions

- All secrets go in `.env` (gitignored)
- Branding changes go in `branding/`
- nginx config goes in `nginx/`
- Deployment scripts go in `scripts/`
- No comments in production code unless explaining non-obvious behavior

## Testing Changes

Always run `bash scripts/verify.sh` after any change to confirm:
- Ghost blog still works
- Unauthenticated /terminal/ returns 401
- Authenticated /terminal/ returns 200
- Security headers present
- Container healthy
