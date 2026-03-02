# bitroot-ops

Central operations repo for Bitroot's OnePlus 6 cloud server.

## Contents

```
.github/workflows/
  deploy.yml          — reusable deploy workflow (call from project repos)

scripts/
  setup-deploy-key.sh — one-time SSH key setup helper

docs/
  bitroot-server-guide.md   — server architecture + CLI reference
  bitroot-employee-setup.md — step-by-step guide for new team members
```

## Quick Start

### Using the reusable deploy workflow

In your project repo, create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: bitroot-org/bitroot-ops/.github/workflows/deploy.yml@main
    with:
      project_name: your-project-name
    secrets: inherit
```

Requires `ONEPLUS_SSH_KEY` secret — see [employee setup guide](docs/bitroot-employee-setup.md).

### First-time setup

```bash
./scripts/setup-deploy-key.sh bitroot-org/bitroot-ops
```
