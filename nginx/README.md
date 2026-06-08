# Terminal King Terminal — nginx-proxy Integration

## How It Works

The server already runs `nginx-proxy` + `acme-companion` which:

1. Watches Docker containers for `VIRTUAL_HOST` labels
2. Auto-generates nginx server blocks with HTTPS
3. Routes traffic to containers by hostname

Terminal King Terminal integrates by:
- Sharing the `nginx-proxy` Docker network
- Using a **vhost.d location override** to add `/terminal/` path routing
- Adding HTTP Basic Auth at the nginx layer (before the app)

## Setup Steps

### 1. Place the vhost override

Copy `vhost-terminalking.conf` into the nginx-proxy vhost.d volume:

```bash
# Find the vhost volume mountpoint
VHOST_VOL=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/vhost.d"}}{{.Name}}{{end}}{{end}}')
VHOST_PATH=$(docker volume inspect "$VHOST_VOL" --format '{{.Mountpoint}}')

# Copy the config
sudo cp nginx/vhost-terminalking.conf "$VHOST_PATH/terminalking.com"
```

### 2. Place the htpasswd file

The vhost config references `/etc/nginx/htpasswd/terminalking.htpasswd`.
Create this inside the nginx-proxy container:

```bash
# Create htpasswd directory in the vhost volume
sudo mkdir -p "$VHOST_PATH/htpasswd"

# Generate the htpasswd file
htpasswd -cbB "$VHOST_PATH/htpasswd/terminalking.htpasswd" admin YOUR_PASSWORD
```

### 3. Reload nginx-proxy

```bash
docker exec nginx-proxy nginx -s reload
```

### 4. Verify

```bash
# Should return 401
curl -I https://terminalking.com/terminal/

# Should return 200 (with valid credentials)
curl -I -u admin:YOUR_PASSWORD https://terminalking.com/terminal/

# Ghost blog should still work
curl -I https://terminalking.com/
```

## Alternative: Custom nginx-proxy Compose

If you prefer to manage the htpasswd via Docker volumes, add this to the
nginx-proxy service in `proxy/docker-compose.yml`:

```yaml
volumes:
  - /var/www/terminalking.com/terminal-king-terminal/.htpasswd:/etc/nginx/htpasswd/terminalking.htpasswd:ro
  # ... existing mounts
```

Then restart the proxy stack.
