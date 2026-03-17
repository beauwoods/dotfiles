#!/bin/bash
# bootstrap.sh
# Run this once on a fresh Mac before the Ansible playbook.
#
# Usage (no repo needed — downloads itself):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/dotfiles/main/scripts/bootstrap.sh)"
#
# Or if you already have the repo cloned:
#   ~/Documents/GitHub/dotfiles/scripts/bootstrap.sh

set -euo pipefail

# Cache sudo credentials upfront — several steps need root.
# Entering password once here means you can walk away for the rest.
echo "This script needs sudo access. Please enter your password now."
sudo -v
# Keep-alive: refresh sudo timestamp every 60s until script exits
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 1: Install Xcode Command Line Tools"
echo "    (provides git, python3, and compiler tools needed for everything else)"

if xcode-select -p &>/dev/null; then
  echo "    Already installed at: $(xcode-select -p)"
else
  xcode-select --install 2>/dev/null || true
  echo ""
  echo "    A dialog has appeared asking you to install the Command Line Tools."
  echo "    Click 'Install' and wait for it to finish."
  echo "    Do NOT click 'Get Xcode' — just 'Install'."
  echo ""
  WAIT=0
  TIMEOUT=600
  until xcode-select -p &>/dev/null; do
    sleep 10
    WAIT=$((WAIT+10))
    echo -n "."
    if [ "$WAIT" -ge "$TIMEOUT" ]; then
      echo ""
      echo "ERROR: Timed out after ${TIMEOUT}s waiting for Xcode CLI tools."
      echo "Install manually with: xcode-select --install"
      echo "Then re-run this script."
      exit 1
    fi
  done
  echo ""
  echo "    Xcode CLI tools installed."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 2: Clone dotfiles repo"
DOTFILES_DIR="$HOME/Documents/GitHub/dotfiles"
REPO_URL="https://github.com/beauwoods/dotfiles.git"

if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "    Repo already exists — pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only
  echo "    Up to date."
else
  echo "    Cloning $REPO_URL → $DOTFILES_DIR"
  mkdir -p "$HOME/Documents/GitHub"
  git clone "$REPO_URL" "$DOTFILES_DIR"
  echo "    Clone complete."
fi

# If invoked via curl | bash, re-exec from the cloned copy so the rest of
# the script is the authoritative version from the repo.
SELF="$DOTFILES_DIR/scripts/bootstrap.sh"
if [ "$0" != "$SELF" ] && [ -f "$SELF" ]; then
  echo ""
  echo "    Re-running from cloned repo: $SELF"
  exec bash "$SELF" "$@"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 3: Install pending macOS software updates"
echo "    This ensures the OS is fully patched before setup begins."
echo ""

# softwareupdate exits non-zero if no updates are available on some macOS
# versions — || true prevents aborting under set -e.
# --restart is intentionally omitted: if a restart is required we detect it
# and ask you to restart manually, rather than rebooting mid-script.
UPDATE_OUTPUT=$(softwareupdate --install --all 2>&1 || true)
echo "$UPDATE_OUTPUT"

if echo "$UPDATE_OUTPUT" | grep -qi "restart"; then
  echo ""
  echo "  *** A restart is required to finish installing updates. ***"
  echo "  Please restart, then re-run bootstrap.sh:"
  echo "    $SELF"
  exit 0
else
  echo "  Updates complete (or none needed)."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 4: Install Ansible via pip3..."

# --break-system-packages is required on macOS Sequoia (15+) where Python is
# marked as externally managed. Older pip versions don't know this flag, so
# we try with it first and fall back without.
if python3 -m pip install --user ansible --break-system-packages 2>/dev/null; then
  echo "    Ansible installed."
elif python3 -m pip install --user ansible 2>/dev/null; then
  echo "    Ansible installed (without --break-system-packages)."
else
  echo "ERROR: pip install failed. Try manually:"
  echo "  python3 -m pip install --user ansible"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 5: Install Ansible Galaxy roles..."

# Resolve ansible-galaxy — pip --user installs to ~/Library/Python/X.Y/bin/
GALAXY_BIN=""
for candidate in \
    ~/.local/bin/ansible-galaxy \
    ~/Library/Python/3.9/bin/ansible-galaxy \
    ~/Library/Python/3.13/bin/ansible-galaxy \
    ~/Library/Python/3.12/bin/ansible-galaxy \
    ~/Library/Python/3.11/bin/ansible-galaxy \
    ~/Library/Python/3.10/bin/ansible-galaxy \
    /usr/local/bin/ansible-galaxy; do
  [ -x "$candidate" ] && GALAXY_BIN="$candidate" && break
done
if [ -z "$GALAXY_BIN" ]; then
  GALAXY_BIN=$(python3 -c "import shutil; print(shutil.which('ansible-galaxy') or '')" 2>/dev/null || true)
fi

if [ -z "$GALAXY_BIN" ]; then
  echo "WARNING: ansible-galaxy not found. Run manually after adding pip bin to PATH:"
  echo "  ansible-galaxy install -r $DOTFILES_DIR/ansible/requirements.yml"
else
  "$GALAXY_BIN" install -r "$DOTFILES_DIR/ansible/requirements.yml"
  echo "    Galaxy roles installed."
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Step 6: Verify Ansible install..."

PLAYBOOK_BIN=""
for candidate in \
    ~/.local/bin/ansible-playbook \
    ~/Library/Python/3.9/bin/ansible-playbook \
    ~/Library/Python/3.13/bin/ansible-playbook \
    ~/Library/Python/3.12/bin/ansible-playbook \
    ~/Library/Python/3.11/bin/ansible-playbook \
    ~/Library/Python/3.10/bin/ansible-playbook \
    /usr/local/bin/ansible-playbook; do
  [ -x "$candidate" ] && PLAYBOOK_BIN="$candidate" && break
done
if [ -z "$PLAYBOOK_BIN" ]; then
  PLAYBOOK_BIN=$(python3 -c "import shutil; print(shutil.which('ansible-playbook') or '')" 2>/dev/null || true)
fi

if [ -z "$PLAYBOOK_BIN" ]; then
  echo "WARNING: ansible-playbook not found."
  echo "Add pip's bin directory to your PATH, then re-run."
  echo "  python3 -m pip show ansible | grep Location"
  PLAYBOOK_BIN="ansible-playbook"
else
  echo "Found: $PLAYBOOK_BIN"
  "$PLAYBOOK_BIN" --version | head -1 || true
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "==> Bootstrap complete."
echo ""
echo "Next steps (see MANUAL_STEPS.md for full detail):"
echo ""
echo "  Stage 2 — First Ansible run (apps + defaults, no auth needed):"
echo "    cd $DOTFILES_DIR/ansible"
echo "    $PLAYBOOK_BIN main.yml -i inventory/localhost --ask-become-pass --tags apps,defaults"
echo ""
echo "  Stage 3 — Auth session (App Store, 1Password, Adobe, SetApp, Little Snitch)"
echo ""
echo "  Stage 4 — Second Ansible run (App Store + config):"
echo "    $PLAYBOOK_BIN main.yml -i inventory/localhost --ask-become-pass --tags mas,config"
