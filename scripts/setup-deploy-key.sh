#!/bin/bash
# setup-deploy-key.sh
# One-time setup: generate an ed25519 deploy key and configure SSH + GitHub secret.
# Run this from your LOCAL Mac — NOT on the OnePlus.
#
# Prerequisites:
#   - gh CLI installed and authenticated (gh auth login)
#   - SSH access to the OnePlus (password auth still enabled)
#
# Usage:
#   ./setup-deploy-key.sh [github-org/repo] [oneplus-ssh-host]
#
# Example:
#   ./setup-deploy-key.sh bitroot-org/bitroot-ops ssh-oneplus.bitroot.in

set -e

REPO="${1:-bitroot-org/bitroot-ops}"
ONEPLUS_HOST="${2:-ssh-oneplus.bitroot.in}"
ONEPLUS_USER="${3:-u0_a238}"
ONEPLUS_PORT="${4:-22}"
KEY_FILE="$HOME/.ssh/oneplus-deploy-key"
KEY_COMMENT="github-actions-deploy"

echo "=== OnePlus Deploy Key Setup ==="
echo ""
echo "  repo:   $REPO"
echo "  host:   $ONEPLUS_HOST"
echo "  user:   $ONEPLUS_USER"
echo "  port:   $ONEPLUS_PORT"
echo "  key:    $KEY_FILE"
echo ""

# ── step 1: generate keypair ──────────────────────────────────────────────────
if [ -f "$KEY_FILE" ]; then
  echo "step 1: key already exists at $KEY_FILE — skipping generation"
  echo "  (delete it and re-run if you want a fresh key)"
else
  echo "step 1: generating ed25519 keypair..."
  ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$KEY_FILE" -N ""
  echo "  generated: $KEY_FILE (private) + ${KEY_FILE}.pub (public)"
fi

echo ""

# ── step 2: add public key to OnePlus authorized_keys ─────────────────────────
echo "step 2: adding public key to OnePlus authorized_keys..."
echo "  (you'll be prompted for the OnePlus SSH password: termux123)"
echo ""

PUB_KEY=$(cat "${KEY_FILE}.pub")

ssh -p "$ONEPLUS_PORT" "${ONEPLUS_USER}@${ONEPLUS_HOST}" \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
   echo '${PUB_KEY}' >> ~/.ssh/authorized_keys && \
   chmod 600 ~/.ssh/authorized_keys && \
   echo '  public key added to authorized_keys'"

echo ""

# ── step 3: verify key-based login works ──────────────────────────────────────
echo "step 3: verifying key-based login..."
ssh -i "$KEY_FILE" -p "$ONEPLUS_PORT" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  "${ONEPLUS_USER}@${ONEPLUS_HOST}" \
  "echo '  key auth works!'"
echo ""

# ── step 4: store private key as GitHub secret ────────────────────────────────
echo "step 4: storing private key as GitHub secret ONEPLUS_SSH_KEY..."
if command -v gh &>/dev/null; then
  # Set secret on all repos that need it, or just the org-level secret
  gh secret set ONEPLUS_SSH_KEY --repo "$REPO" < "$KEY_FILE"
  echo "  secret set on $REPO"
  echo ""
  echo "  TIP: to set it on all project repos without re-running this script:"
  echo "    gh secret set ONEPLUS_SSH_KEY --org bitroot-org --visibility selected < $KEY_FILE"
else
  echo "  gh CLI not found — set the secret manually:"
  echo ""
  echo "  1. Go to: https://github.com/$REPO/settings/secrets/actions/new"
  echo "  2. Name:  ONEPLUS_SSH_KEY"
  echo "  3. Value: paste the contents of $KEY_FILE"
  echo ""
  cat "$KEY_FILE"
fi

echo ""

# ── step 5: security reminder ─────────────────────────────────────────────────
echo "=== NEXT STEPS ==="
echo ""
echo "  1. Add log rotation cron on the OnePlus:"
echo "     ssh -i $KEY_FILE -p $ONEPLUS_PORT ${ONEPLUS_USER}@${ONEPLUS_HOST}"
echo "     crontab -e"
echo "     add:  0 3 * * * pm2 flush && find ~/Downloads -name '*.log' -mtime +7 -delete"
echo ""
echo "  2. (Optional) Disable password auth after confirming key works:"
echo "     On the OnePlus, run:"
echo "       echo 'PasswordAuthentication no' >> \$PREFIX/etc/ssh/sshd_config"
echo "       sshd  # restart sshd"
echo ""
echo "  3. Rotate the GitHub NPM token in .npmrc — it was exposed."
echo ""
echo "Done."
