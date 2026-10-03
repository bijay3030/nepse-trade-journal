# Deploying

One small server runs the API, its jobs and PostgreSQL; the frontend is a static site.

```
browser ── https://<project>.pages.dev  (Cloudflare Pages: React build)
   │
   └─ API ── https://api.<server-ip>.sslip.io   (Caddy → Rails/Puma + Solid Queue → PostgreSQL)
```

## 1. Server (Oracle Cloud Always Free, or any Ubuntu 22.04/24.04 VM)

Create an Ubuntu VM with a public IP, open TCP 80 and 443 in the cloud firewall
(Oracle: the subnet's security list), and add the public key from
`~/.ssh/nepse_oracle_ed25519.pub`. Then, from this repository:

```bash
echo 'DEPLOY_HOST=ubuntu@<server-ip>' > deploy/target.env
FRONTEND_ORIGINS=https://<project>.pages.dev bin/deploy setup
bin/deploy push        # builds the image on the server and starts everything
bin/deploy copy-data   # optional: replace the server's data with your local database
```

`setup` installs Docker, opens ports 80/443 in the host firewall, turns on security
updates and a daily 02:30 backup (14 days kept in `~/nepse-journal/backups`), and writes
`deploy/.env` on the server with generated secrets plus your `config/master.key`.
The API answers on `https://api.<server-ip-with-dashes>.sslip.io` (a free hostname that
resolves to the IP); Caddy gets the HTTPS certificate on first request.

## 2. Your login

There is no public sign-up. On the server:

```bash
bin/deploy console
bin/rails users:list
bin/rails 'users:rename[trader@nepse.com,you@example.com]'   # if you copied local data
bin/rails 'users:set_password[you@example.com]'              # hidden prompt
# or, on an empty database:
bin/rails 'users:create[you@example.com]'
```

## 3. Frontend (Cloudflare Pages)

Workers & Pages → Create → Pages → Connect to Git → this repository:

| Setting | Value |
| ------- | ----- |
| Production branch | `initial-app-setup` |
| Root directory | `frontend` |
| Build command | `npm ci && npm run build` |
| Build output | `dist` |
| Environment variables | `VITE_API_BASE_URL=https://api.<server-ip>.sslip.io/api/v1`, `VITE_CABLE_URL=wss://api.<server-ip>.sslip.io/cable` |

`frontend/public/_redirects` sends every path to the app, and `frontend/.npmrc` allows
the existing peer-dependency mismatch. Every push to the branch redeploys.

## 4. Telegram

Production uses the bot token from the encrypted credentials. Development now ignores
it unless `TELEGRAM_IN_DEVELOPMENT=true`, so your laptop and the server don't both poll
the bot. Link your chat again from the live app's Settings → Telegram.

## Later: your own domain (.com.np)

Point `api.<domain>` at the server IP (A record) and the domain at Cloudflare Pages, then
on the server edit `deploy/.env` (`API_HOST`, `API_HOSTS`, `FRONTEND_ORIGINS`), run
`bin/deploy push`, and update the two Pages variables.

## Day to day

`bin/deploy push` after merging changes · `bin/deploy logs` · `bin/deploy status` ·
`bin/deploy backup` · restore: see the comment in `deploy/backup.sh`.
