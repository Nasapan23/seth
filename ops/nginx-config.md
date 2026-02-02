# nginx Configuration for Seth

Add this server block to your existing nginx stack configuration.

## Server Block

```nginx
# Seth - OpenClaw Assistant
# Add to your nginx configuration

upstream seth_backend {
    server seth:18789;
    keepalive 32;
}

server {
    listen 80;
    server_name seth.nisipeanutech.ro;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name seth.nisipeanutech.ro;

    # SSL Configuration (adjust paths for your setup)
    ssl_certificate /etc/letsencrypt/live/seth.nisipeanutech.ro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/seth.nisipeanutech.ro/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Rate Limiting (adjust as needed)
    limit_req_zone $binary_remote_addr zone=seth_limit:10m rate=10r/s;
    limit_req zone=seth_limit burst=20 nodelay;

    # Logging
    access_log /var/log/nginx/seth.access.log;
    error_log /var/log/nginx/seth.error.log;

    # Root location - proxy to Seth
    location / {
        proxy_pass http://seth_backend;
        proxy_http_version 1.1;
        
        # WebSocket support (required for OpenClaw)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Preserve headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts for long-running requests
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Buffer settings
        proxy_buffering off;
        proxy_buffer_size 4k;
    }

    # Health check endpoint (optional, for monitoring)
    location /health {
        proxy_pass http://seth_backend/health;
        proxy_http_version 1.1;
        
        # Don't log health checks
        access_log off;
    }
}
```

## Network Configuration

Since both nginx and Seth are in Portainer, you need to connect them via Docker network.

### Option 1: External Network (Recommended)

1. Create an external network in Portainer:
   - Networks > Add network
   - Name: `proxy_net`
   - Driver: bridge

2. Add to Seth's compose.yml:

```yaml
networks:
  seth_net:
    driver: bridge
  proxy_net:
    external: true

services:
  seth:
    networks:
      - seth_net
      - proxy_net
```

3. Add to nginx's compose.yml:

```yaml
networks:
  proxy_net:
    external: true

services:
  nginx:
    networks:
      - proxy_net
```

### Option 2: Use Container Name with Full Network

If using Portainer's default networks, use the full container name:

```nginx
upstream seth_backend {
    # Use the full container name with stack prefix
    server seth-seth-1:18789;
    # Or check actual container name in Portainer
}
```

## SSL Certificate

### With Certbot (Let's Encrypt)

If your nginx stack includes certbot:

```bash
# Generate certificate
certbot certonly --webroot -w /var/www/certbot -d seth.nisipeanutech.ro
```

### With nginx-proxy + acme-companion

If using jwilder/nginx-proxy with acme-companion, add these labels to Seth:

```yaml
services:
  seth:
    labels:
      - "VIRTUAL_HOST=seth.nisipeanutech.ro"
      - "VIRTUAL_PORT=18789"
      - "LETSENCRYPT_HOST=seth.nisipeanutech.ro"
      - "LETSENCRYPT_EMAIL=your@email.com"
```

## Testing

### Test nginx Config

```bash
docker exec nginx nginx -t
```

### Test Connectivity

```bash
# From nginx container
curl -v http://seth:18789/health

# From outside
curl -v https://seth.nisipeanutech.ro/health
```

### Test WebSocket

Open browser DevTools, go to Network tab, filter by WS, and load the WebChat.

## Troubleshooting

### 502 Bad Gateway

- Check Seth container is running: `docker ps | grep seth`
- Check network connectivity between nginx and Seth
- Verify upstream server name matches container name

### WebSocket Not Connecting

- Ensure `Upgrade` and `Connection` headers are passed
- Check `proxy_read_timeout` is sufficient
- Verify SSL termination is correct

### Authentication Issues

The gateway token is passed via the WebChat UI. If you need to pass it via nginx:

```nginx
# NOT recommended - exposes token in config
# proxy_set_header Authorization "Bearer YOUR_TOKEN";

# Better: Let WebChat handle token via localStorage
```
