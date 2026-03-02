# Bitroot OnePlus Server Guide

> OnePlus 6 running Termux as a self-hosted cloud server with Cloudflare Tunnel.

---

## Access

```bash
ssh u0_a238@ssh-oneplus.bitroot.in -p 22
```

Or with a deploy key:
```bash
ssh -i ~/.ssh/oneplus-deploy-key u0_a238@ssh-oneplus.bitroot.in
```

---

## Project CLI

All project management is done via `~/bin/project`.

### Commands

| Command | Description |
|---|---|
| `project clone <name> <repo> <port>` | Clone repo, register with PM2, add Cloudflare route |
| `project deploy <name>` | git pull + npm ci + pm2 restart |
| `project env <name> KEY=VALUE` | Write env vars to `~/Downloads/<name>/.env` |
| `project remove <name>` | PM2 delete + remove tunnel + deregister port |
| `project add <name> <port> [cmd]` | Register existing directory with PM2 |
| `project start/stop/restart <name>` | PM2 lifecycle |
| `project logs <name>` | Tail PM2 logs (last 50 lines) |
| `project status` | All projects + URLs + PM2 status |
| `project url <name>` | Print project URL |

### Onboard a new project

```bash
ssh u0_a238@ssh-oneplus.bitroot.in
project clone myapp https://github.com/bitroot-org/myapp 3001
# → clones to ~/Downloads/myapp
# → registers with PM2
# → adds myapp.bitroot.in → localhost:3001 to Cloudflare tunnel
# → prints checklist + live URL
```

After cloning, set any env vars needed:
```bash
project env myapp DATABASE_URL=... JWT_SECRET=...
project restart myapp
```

---

## Port Registry

`~/bin/ports.conf` — flat file mapping `<name>=<port>`.

The `project` CLI manages this file automatically. **Never reuse a port** — the CLI enforces uniqueness.

Suggested ranges:
- `3000-3099` — API services
- `3100-3199` — frontend dev servers
- `3200-3299` — internal tools

---

## Cloudflare Tunnel

Config: `~/.cloudflared/config.yml`

Each project entry:
```yaml
- hostname: myapp.bitroot.in
  service: http://localhost:3001
```

`project clone` and `project remove` manage this file automatically. `cloudflared` is sent a SIGHUP to reload without restart.

### Add a manual route

```bash
tunnel-add myapp 3001
```

---

## Process Manager (PM2)

```bash
pm2 list              # show all processes
pm2 logs myapp        # tail logs
pm2 monit             # real-time CPU/RAM dashboard
pm2 save              # persist current process list
```

Config: `~/ecosystem.config.js`

PM2 auto-starts on boot via `~/.termux/boot/start-services.sh`.

---

## Log Rotation

Cron runs at 3am daily:
```
0 3 * * * pm2 flush && find ~/Downloads -name "*.log" -mtime +7 -delete
```

To view/edit crontab: `crontab -e`

---

## Health Check Convention

Every project should expose:
```
GET /health → { status: "ok", uptime: <seconds> }
```

Example (Node.js/Express):
```js
app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});
```

GitHub Actions verifies this endpoint after every deploy.

---

## Boot Sequence

`~/.termux/boot/start-services.sh`:
1. Acquire wake-lock (keeps CPU running)
2. Start `sshd`
3. Start PM2 (resurrects saved process list)
4. Start `cloudflared` (auto-restarts via watchdog cron)

Tunnel watchdog: `~/bin/tunnel-watchdog` — cron every 3 min.

---

## Security

- SSH: ed25519 key auth (GitHub Actions deploy key in `~/.ssh/authorized_keys`)
- Password auth: disabled after key setup
- Cloudflare Tunnel: all traffic proxied via Cloudflare — no port exposure to internet
- `.env` files: stored in project directory, never committed

---

## Directory Layout

```
~/
├── bin/
│   ├── project          # project manager CLI
│   ├── ports.conf       # port registry
│   └── tunnel-add       # manual tunnel route helper
├── Downloads/           # all project repositories
│   ├── bitroot-api/
│   └── ...
├── ecosystem.config.js  # PM2 process definitions
└── .cloudflared/
    └── config.yml       # Cloudflare tunnel routing
```
