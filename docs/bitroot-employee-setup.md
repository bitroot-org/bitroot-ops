# Bitroot Employee Setup — OnePlus Cloud Server

> How to deploy a new project end-to-end: SSH in, clone the repo, set up GitHub Actions, ship it.

---

## 1. SSH Access

You'll need the OnePlus SSH key from the team password manager (1Password / Vault).

```bash
# Save the private key
cat > ~/.ssh/oneplus-deploy-key << 'EOF'
<paste private key here>
EOF
chmod 600 ~/.ssh/oneplus-deploy-key

# Add to ~/.ssh/config for convenience
cat >> ~/.ssh/config << 'EOF'
Host oneplus
  HostName ssh-oneplus.bitroot.in
  User u0_a238
  Port 22
  IdentityFile ~/.ssh/oneplus-deploy-key
  StrictHostKeyChecking accept-new
EOF

# Test
ssh oneplus "echo 'connected!'"
```

---

## 2. Deploy a New Project (one-time)

```bash
ssh oneplus

# Clone repo, register with PM2, add Cloudflare route
project clone <name> <repo-url> <port>

# Example:
project clone myapi https://github.com/bitroot-org/myapi 3005
```

This single command:
- Clones to `~/Downloads/<name>`
- Runs `npm install`
- Registers in `ecosystem.config.js` (PM2)
- Starts the process
- Adds `<name>.bitroot.in → localhost:<port>` to Cloudflare tunnel
- Reloads cloudflared
- Prints the live URL

Then set any required env vars:
```bash
project env myapi DATABASE_URL=postgres://... JWT_SECRET=abc123
project restart myapi
```

Verify it's live:
```bash
project url myapi          # prints URL
curl https://myapi.bitroot.in/health   # should return {"status":"ok"}
```

---

## 3. Add the Health Check Endpoint

Every project **must** expose `GET /health`. Add this to your Express/Node app:

```js
// health.js (or inline in server entry point)
app.get('/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});
```

GitHub Actions will poll this after deploy. If it doesn't exist, you'll get a warning (not a failure).

---

## 4. Set Up GitHub Actions (CI/CD)

### 4a. Add the deploy key as a GitHub secret

If the `ONEPLUS_SSH_KEY` secret is already set org-wide, skip this step.

Otherwise, run the setup script from your local machine:
```bash
# Requires: gh CLI installed + authenticated
cd bitroot-ops/
./scripts/setup-deploy-key.sh bitroot-org/bitroot-ops
```

Or manually:
1. Get the private key from the team vault
2. Go to `github.com/<org>/<repo>/settings/secrets/actions/new`
3. Name: `ONEPLUS_SSH_KEY`
4. Value: paste the ed25519 private key

### 4b. Add the caller workflow to your project repo

Create `.github/workflows/deploy.yml` in your project:

```yaml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    uses: bitroot-org/bitroot-ops/.github/workflows/deploy.yml@main
    with:
      project_name: myapi    # ← your project name (must match ports.conf)
    secrets: inherit
```

That's it. Every push to `main` will:
1. SSH into the OnePlus
2. Run `project deploy myapi` (`git pull` + `npm ci` + `pm2 restart`)
3. Verify `/health` returns 200

---

## 5. Monitoring

```bash
ssh oneplus

project status          # all projects + ports + PM2 status
project logs myapi      # tail logs
pm2 monit               # real-time CPU/RAM per process
```

GitHub Actions history: `github.com/<org>/<repo>/actions`

---

## 6. Port Assignment

Check `~/bin/ports.conf` on the device before picking a port:
```bash
ssh oneplus "cat ~/bin/ports.conf"
```

Suggested ranges:
- `3000-3099` — API services
- `3100-3199` — frontend dev servers

The `project clone` CLI will error if you try to reuse a port.

---

## 7. Removing a Project

```bash
ssh oneplus
project remove myapi
# Note: project files in ~/Downloads/myapi are NOT deleted
# To fully delete: rm -rf ~/Downloads/myapi
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `ssh: connect to host ssh-oneplus.bitroot.in: Connection refused` | Phone may be sleeping. Wake it up physically, then check `termux-wake-lock` is running |
| `project deploy` fails with `npm ci` error | `npm ci` requires a `package-lock.json` — make sure it's committed |
| Tunnel route not resolving | `cloudflared` may have crashed. SSH in and run: `pkill cloudflared && cloudflared tunnel run &` |
| PM2 process in "errored" state | `project logs <name>` to see the error, then fix + `project restart <name>` |
| GitHub Actions `ONEPLUS_SSH_KEY` permission denied | Re-run `setup-deploy-key.sh` to regenerate and re-register the key |
