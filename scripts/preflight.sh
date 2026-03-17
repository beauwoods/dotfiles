#!/bin/bash
# preflight.sh
# Run this on your OLD machine before deployment day.
# Captures configs and private data to iCloud Drive so they're available
# on the new machine when bootstrap.sh runs.
#
# Usage:
#   chmod +x ~/mac-config/scripts/preflight.sh
#   ~/mac-config/scripts/preflight.sh

set -euo pipefail

LOG_DIR="$HOME/.local/share/mac-setup/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/preflight_$(date +%Y%m%d_%H%M%S).log"

# Private configs go to iCloud Drive — syncs automatically to the new machine.
PRIVATE_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/dotfiles-private"
ISSUES=0

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}==>${NC} $*" | tee -a "$LOG"; }
ok()      { echo -e "${GREEN} ✓${NC} $*" | tee -a "$LOG"; }
warn()    { echo -e "${YELLOW} ⚠${NC} $*" | tee -a "$LOG"; ISSUES=$((ISSUES+1)); }
fail()    { echo -e "${RED} ✗${NC} $*" | tee -a "$LOG"; ISSUES=$((ISSUES+1)); }
section() {
  echo "" | tee -a "$LOG"
  echo -e "${BLUE}────────────────────────────────────────${NC}" | tee -a "$LOG"
  echo -e "${BLUE}$*${NC}" | tee -a "$LOG"
  echo -e "${BLUE}────────────────────────────────────────${NC}" | tee -a "$LOG"
}

echo "" > "$LOG"
echo "Pre-flight run: $(date)" >> "$LOG"
echo ""
echo "Private dir:   $PRIVATE_DIR"
echo "Log:           $LOG"
echo ""

# Verify iCloud Drive is available before proceeding
if [ ! -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]; then
  echo ""
  warn "iCloud Drive not found at expected path."
  warn "Sign into iCloud and enable iCloud Drive, then re-run preflight."
  warn "Private configs (shell dotfiles, SSH config, signatures) cannot be captured without it."
else
  mkdir -p "$PRIVATE_DIR"
  ok "iCloud Drive found. Private configs will sync to: $PRIVATE_DIR"
fi
echo ""

# Cache sudo credentials for the defaults capture section
echo "This script needs sudo access for some operations."
sudo -v
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ─────────────────────────────────────────────────────────────────────────────
section "1/8 — SSH Keys"
# ─────────────────────────────────────────────────────────────────────────────

SSH_PRIVATE_DEST="$PRIVATE_DIR/ssh"
mkdir -p "$SSH_PRIVATE_DEST"

if [ -d ~/.ssh ]; then
  log "Capturing ~/.ssh/ → iCloud private ..."

  if [ -f ~/.ssh/config ]; then
    cp ~/.ssh/config "$SSH_PRIVATE_DEST/config"
    ok "Copied ~/.ssh/config → iCloud private"
  else
    warn "~/.ssh/config not found — create one with the 1Password IdentityAgent line before deployment day."
  fi

  PUBKEY_COUNT=0
  for pubkey in ~/.ssh/*.pub; do
    [ -f "$pubkey" ] || continue
    cp "$pubkey" "$SSH_PRIVATE_DEST/"
    ok "Copied $(basename "$pubkey") → iCloud private"
    PUBKEY_COUNT=$((PUBKEY_COUNT+1))
  done
  [ "$PUBKEY_COUNT" -eq 0 ] && log "No public keys found in ~/.ssh/ (fine if using 1Password agent)."

  # Private keys — log but don't copy; generate fresh on new machine
  PRIVATE_FOUND=()
  for key in ~/.ssh/*; do
    [ -f "$key" ] || continue
    base=$(basename "$key")
    [[ "$base" == *.pub ]]             && continue
    [[ "$base" == "config" ]]          && continue
    [[ "$base" == "known_hosts"* ]]    && continue
    [[ "$base" == "authorized_keys" ]] && continue
    if grep -q "PRIVATE KEY\|BEGIN OPENSSH" "$key" 2>/dev/null; then
      PRIVATE_FOUND+=("$base")
    fi
  done

  if [ ${#PRIVATE_FOUND[@]} -gt 0 ]; then
    log "Found private keys in ~/.ssh/: ${PRIVATE_FOUND[*]}"
    log "Not capturing them — the new machine will generate fresh keys."
    log "If you need emergency access: store in 1Password (SSH Key item type)."
  fi

  chmod 700 "$SSH_PRIVATE_DEST"
  chmod 644 "$SSH_PRIVATE_DEST"/*.pub 2>/dev/null || true
  [ -f "$SSH_PRIVATE_DEST/config" ] && chmod 600 "$SSH_PRIVATE_DEST/config" || true

  ok "SSH capture complete → iCloud private"
else
  warn "~/.ssh/ not found — skipping."
fi

# ─────────────────────────────────────────────────────────────────────────────
section "2/8 — Shell Dotfiles & Git Config"
# ─────────────────────────────────────────────────────────────────────────────

SHELL_DEST="$PRIVATE_DIR/shell"
mkdir -p "$SHELL_DEST"

SHELL_FILES=(
  ~/.zshrc
  ~/.zprofile
  ~/.zshenv
  ~/.bash_profile
  ~/.bashrc
  ~/.profile
  ~/.gitconfig
  ~/.gitignore_global
)

for f in "${SHELL_FILES[@]}"; do
  if [ -f "$f" ]; then
    cp "$f" "$SHELL_DEST/$(basename "$f")"
    ok "Captured $(basename "$f")"
  fi
done

if [ -f ~/.gitconfig ]; then
  GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
  GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
  if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
    ok "Git config: $GIT_NAME <$GIT_EMAIL>"
  else
    warn "Git user.name or user.email not set globally — set on new machine."
  fi
fi

if [ ! -f "$SHELL_DEST/.gitconfig" ]; then
  warn "~/.gitconfig was not captured — git identity won't be set on new machine."
fi
SHELL_COUNT=$(find "$SHELL_DEST" -type f | wc -l | tr -d ' ')
ok "Shell dotfiles captured: $SHELL_COUNT file(s)"

# ─────────────────────────────────────────────────────────────────────────────
section "3/8 — Mail Signatures"
# ─────────────────────────────────────────────────────────────────────────────

SIGS_DIR=$(ls -d ~/Library/Mail/V*/MailData/Signatures 2>/dev/null | tail -1 || true)
SIGS_DEST="$PRIVATE_DIR/mail/signatures.md"
mkdir -p "$PRIVATE_DIR/mail"

if [ -z "$SIGS_DIR" ] || [ ! -d "$SIGS_DIR" ]; then
  warn "Mail signatures directory not found. Is Mail.app configured?"
else
  log "Found signatures at: $SIGS_DIR"
  SIG_COUNT=$(find "$SIGS_DIR" -maxdepth 1 -name "*.mailsignature" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$SIG_COUNT" -eq 0 ]; then
    warn "No .mailsignature files found."
  else
    ok "Found $SIG_COUNT signature(s). Extracting via AppleScript (Mail must be open)..."

    cat > "$SIGS_DEST" << 'HEADER'
# Mail Signatures

Captured by preflight.sh. Re-enter these manually in Mail > Settings > Signatures
after setup, and assign each to its account.

---

HEADER

    AS_TMP=$(mktemp /tmp/preflight_as_XXXXXX.applescript)
    cat > "$AS_TMP" << 'APPLESCRIPT'
tell application "Mail"
  set nameList to {}
  repeat with sig in (every signature)
    set end of nameList to name of sig
  end repeat
  set AppleScript's text item delimiters to linefeed
  return nameList as text
end tell
APPLESCRIPT
    MAIL_SIG_NAMES=$(osascript "$AS_TMP" 2>/dev/null) || MAIL_SIG_NAMES=""
    rm -f "$AS_TMP"

    SIGS_EXTRACTED=0
    SIGS_FAILED=0

    if [ -z "$MAIL_SIG_NAMES" ]; then
      warn "AppleScript could not get signature names from Mail. Is Mail.app open?"
    else
      log "Mail signatures found: $(echo "$MAIL_SIG_NAMES" | tr '\n' ',' | sed 's/,$//')"
    fi

    while IFS= read -r SIG_NAME; do
      [ -z "$SIG_NAME" ] && continue

      AS_TMP2=$(mktemp /tmp/preflight_as_XXXXXX.applescript)
      cat > "$AS_TMP2" << APPLESCRIPT
tell application "Mail"
  repeat with sig in (every signature)
    try
      if name of sig is "$SIG_NAME" then
        return content of sig
      end if
    end try
  end repeat
  return ""
end tell
APPLESCRIPT
      HTML_CONTENT=$(osascript "$AS_TMP2" 2>/dev/null) || HTML_CONTENT=""
      rm -f "$AS_TMP2"

      {
        echo "## $SIG_NAME"
        echo ""
        echo "**Account assignment:** [fill in — check Mail > Settings > Signatures on old machine]"
        echo ""
        echo "**HTML content:**"
        echo '```html'
        if [ -n "$HTML_CONTENT" ]; then
          echo "$HTML_CONTENT"
          SIGS_EXTRACTED=$((SIGS_EXTRACTED+1))
        else
          echo "[Could not extract content for: $SIG_NAME]"
          SIGS_FAILED=$((SIGS_FAILED+1))
        fi
        echo '```'
        echo ""
        echo "---"
        echo ""
      } >> "$SIGS_DEST"

      ok "Captured signature: $SIG_NAME"
    done <<< "$MAIL_SIG_NAMES"

    if [ "$SIGS_FAILED" -gt 0 ]; then
      warn "Extracted $SIGS_EXTRACTED/$SIG_COUNT signatures. $SIGS_FAILED need manual capture — see $SIGS_DEST"
    else
      ok "All $SIGS_EXTRACTED signatures extracted successfully."
    fi
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "4/8 — Manual Export Reminders"
# ─────────────────────────────────────────────────────────────────────────────

# iTerm2
ITERM_APP=""
[ -d "/Applications/iTerm.app" ] && ITERM_APP="/Applications/iTerm.app"
[ -d "/Applications/iTerm2.app" ] && ITERM_APP="/Applications/iTerm2.app"

if [ -n "$ITERM_APP" ]; then
  ITERM_PREFS=$(defaults read com.googlecode.iterm2 PrefsCustomFolder 2>/dev/null || true)
  ITERM_PREFS="${ITERM_PREFS/#\~/$HOME}"
  EXPECTED_ITERM_DIR="$PRIVATE_DIR/iterm2"

  if [ -n "$ITERM_PREFS" ] && [ -d "$ITERM_PREFS" ]; then
    if [ "$ITERM_PREFS" != "$EXPECTED_ITERM_DIR" ]; then
      warn "iTerm2 prefs folder is set to: $ITERM_PREFS"
      warn "Expected: $EXPECTED_ITERM_DIR"
      echo "  → Open iTerm2 > Settings > General > Preferences"
      echo "  → Change the folder to exactly: $EXPECTED_ITERM_DIR"
      echo "  → Click 'Save Current Settings to Folder'"
    else
      mkdir -p "$EXPECTED_ITERM_DIR"
      if cp "$ITERM_PREFS"/*.plist "$EXPECTED_ITERM_DIR/" 2>/dev/null; then
        ok "iTerm2 prefs (.plist) copied → iCloud private"
      elif cp "$ITERM_PREFS"/*.json "$EXPECTED_ITERM_DIR/" 2>/dev/null; then
        ok "iTerm2 prefs (.json) copied → iCloud private"
      else
        warn "iTerm2 prefs folder is correct but no plist/json files found yet."
        echo "  → In iTerm2 > Settings > General > Preferences"
        echo "  → Click 'Save Current Settings to Folder' to write the file"
      fi
    fi
  else
    warn "iTerm2: custom prefs folder not configured."
    echo "  → Open iTerm2 > Settings > General > Preferences"
    echo "  → Enable 'Load preferences from a custom folder'"
    echo "  → Set to: $EXPECTED_ITERM_DIR"
    echo "  → Click 'Save Current Settings to Folder'"
  fi
else
  log "iTerm2 not installed — skipping."
fi

# iStat Menus
ISTAT_APP=""
[ -d "/Applications/Setapp/iStat Menus.app" ] && ISTAT_APP="/Applications/Setapp/iStat Menus.app"
[ -d "/Applications/iStat Menus.app" ]         && ISTAT_APP="/Applications/iStat Menus.app"

if [ -n "$ISTAT_APP" ]; then
  ISTAT_DEST="$PRIVATE_DIR/istat"
  mkdir -p "$ISTAT_DEST"
  ISTAT_PLIST=""
  for bid in "com.bjango.istatmenus" "com.bjango.istatmenus5" "com.bjango.istatmenus-setapp"; do
    candidate=~/Library/Preferences/${bid}.plist
    if [ -f "$candidate" ]; then
      ISTAT_PLIST="$candidate"
      break
    fi
  done

  if [ -n "$ISTAT_PLIST" ]; then
    cp "$ISTAT_PLIST" "$ISTAT_DEST/"
    ok "iStat Menus prefs plist copied: $(basename "$ISTAT_PLIST")"
  else
    warn "iStat Menus prefs plist not found at expected path."
  fi
  warn "Also do a GUI export for full settings: iStat Menus menu bar icon > Preferences > Export"
  echo "  → Save as: $ISTAT_DEST/iStatMenusSettings.ismp"
else
  log "iStat Menus not installed — skipping."
fi

# ─────────────────────────────────────────────────────────────────────────────
section "5/8 — Capture Current defaults Values (Reference)"
# ─────────────────────────────────────────────────────────────────────────────

DEFAULTS_DEST="$PRIVATE_DIR/defaults_capture.txt"
log "Capturing defaults values → iCloud private ..."

{
  echo "# defaults capture — $(date)"
  echo "# Reference only. Compare against config.yml and tasks/osx-defaults.yml."
  echo ""

  DOMAINS=(
    "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    "com.apple.AppleMultitouchTrackpad"
    "NSGlobalDomain"
    "com.apple.mail-shared"
    "com.apple.mail"
    "com.apple.dock"
    "com.apple.controlcenter"
    "com.googlecode.iterm2"
    "at.obdev.LittleSnitch"
  )

  for domain in "${DOMAINS[@]}"; do
    echo "## $domain"
    defaults read "$domain" 2>/dev/null || echo "[domain not found or no values set]"
    echo ""
  done
} > "$DEFAULTS_DEST"

ok "defaults captured to iCloud private"

DEFAULTS_SIZE=$(wc -c < "$DEFAULTS_DEST" | tr -d ' ')
if [ "$DEFAULTS_SIZE" -lt 200 ]; then
  warn "defaults_capture.txt looks too small ($DEFAULTS_SIZE bytes) — something may have failed."
else
  ok "defaults_capture.txt: $DEFAULTS_SIZE bytes written."
fi
if grep -q "Clicking = 1" "$DEFAULTS_DEST" 2>/dev/null; then
  ok "Tap-to-click setting confirmed in defaults capture."
else
  warn "Tap-to-click (Clicking = 1) not found — verify trackpad settings before deployment."
fi

# ─────────────────────────────────────────────────────────────────────────────
section "6/8 — Installed App Inventory"
# ─────────────────────────────────────────────────────────────────────────────

APP_DEST="$PRIVATE_DIR/installed_apps.txt"
log "Listing installed applications → iCloud private ..."

{
  echo "# Installed apps — $(date)"
  echo "# Use this to spot apps you forgot to add to config.yml."
  echo ""
  echo "## /Applications"
  ls /Applications/ 2>/dev/null || echo "[empty]"
  echo ""
  echo "## /Applications/Setapp"
  ls "/Applications/Setapp/" 2>/dev/null || echo "[empty or not installed]"
  echo ""
  echo "## ~/Applications"
  ls ~/Applications/ 2>/dev/null || echo "[empty]"
  echo ""
  echo "## App Store apps (via mas)"
  if command -v mas &>/dev/null; then
    mas list
  else
    echo "[mas not installed — install to get App Store list]"
  fi
} > "$APP_DEST"

ok "App inventory written to iCloud private"

APP_COUNT=$(grep "\.app$" "$APP_DEST" | wc -l | tr -d ' ')
ok "Found $APP_COUNT .app entries in inventory."
for EXPECTED_APP in "Google Chrome.app" "1Password.app" "Little Snitch.app"; do
  if grep -q "$EXPECTED_APP" "$APP_DEST" 2>/dev/null; then
    ok "  $EXPECTED_APP found in inventory"
  else
    warn "  $EXPECTED_APP NOT found in inventory — check if it's installed"
  fi
done
warn "Review installed_apps.txt and cross-check against config.yml"

# ─────────────────────────────────────────────────────────────────────────────
section "7/8 — Validation"
# ─────────────────────────────────────────────────────────────────────────────

log "Checking that iCloud private directory has expected content..."

EXPECTED_DIRS=("ssh" "shell" "mail")
for dir in "${EXPECTED_DIRS[@]}"; do
  if [ -d "$PRIVATE_DIR/$dir" ] && [ "$(find "$PRIVATE_DIR/$dir" -type f | wc -l | tr -d ' ')" -gt 0 ]; then
    ok "  $dir/ has files"
  else
    warn "  $dir/ is empty or missing"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
section "8/8 — Ansible Dry Run (--check mode)"
# ─────────────────────────────────────────────────────────────────────────────

# Find this repo (preflight.sh lives in scripts/)
MAC_CONFIG="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v ansible-playbook &>/dev/null; then
  warn "ansible-playbook not found. Install with: pip3 install ansible"
  warn "Skipping dry run."
else
  GEERLING="$HOME/mac-dev-playbook"

  # Clone Geerling's playbook if not present
  if [ ! -d "$GEERLING" ]; then
    log "Cloning geerlingguy/mac-dev-playbook..."
    git clone https://github.com/geerlingguy/mac-dev-playbook.git "$GEERLING"
  fi

  # Install Galaxy dependencies
  log "Installing Ansible Galaxy requirements..."
  ansible-galaxy install -r "$MAC_CONFIG/requirements.yml" 2>&1 | tail -3

  # Set up symlinks (same as bootstrap.sh)
  ln -sf "$MAC_CONFIG/config.yml" "$GEERLING/config.yml"
  for f in "$MAC_CONFIG/tasks"/*.yml; do
    ln -sf "$f" "$GEERLING/tasks/$(basename "$f")"
  done
  ln -sf "$MAC_CONFIG/configs" "$GEERLING/configs"

  log "Running --check mode (no changes will be made)..."
  echo ""

  ANSIBLE_CHECK_LOG="$LOG_DIR/ansible_check_$(date +%Y%m%d_%H%M%S).log"
  cd "$GEERLING"
  if ansible-playbook main.yml \
      --check \
      --ask-become-pass \
      --skip-tags post-auth \
      2>&1 | tee "$ANSIBLE_CHECK_LOG"; then
    ok "Ansible dry run completed. Review output above."
    warn "Tasks marked 'changed' would be applied on deployment day — review them."
  else
    fail "Ansible dry run encountered errors. Fix before deployment day."
    fail "See $ANSIBLE_CHECK_LOG for details."
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "Pre-flight Summary"
# ─────────────────────────────────────────────────────────────────────────────

echo ""
if [ "$ISSUES" -eq 0 ]; then
  echo -e "${GREEN}All checks passed. No issues found.${NC}"
else
  echo -e "${YELLOW}$ISSUES item(s) need attention before deployment day.${NC}"
  echo "  Review the warnings above and in: $LOG"
fi

echo ""
echo "Files captured to iCloud private ($PRIVATE_DIR):"
echo ""
echo "  ssh/config                     — SSH config with host aliases"
echo "  ssh/*.pub                      — public keys (reference)"
echo "  shell/                         — .gitconfig, .zshrc, etc."
echo "  mail/signatures.md             — email signature HTML"
echo "  iterm2/                        — iTerm2 profile (.plist)"
echo "  istat/                         — iStat Menus preferences"
echo "  defaults_capture.txt           — system settings reference"
echo "  installed_apps.txt             — app inventory"
echo ""
echo "Next steps:"
echo "  1. Verify iCloud is syncing: open $PRIVATE_DIR in Finder"
echo "  2. Review installed_apps.txt for apps missing from config.yml"
echo "  3. Review defaults_capture.txt against tasks/osx-defaults.yml"
echo "  4. Set up 1Password SSH agent: ssh-add -l"
echo "  5. Export Termius keys via Termius UI > Preferences > Keychain"
echo "  6. Fill in account assignments in mail/signatures.md"
echo ""
