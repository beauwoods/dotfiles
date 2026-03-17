# Manual Steps — Deployment Day Runbook

Steps marked **[VERIFY]** are handled by Ansible or a config file — your
job is to confirm they took effect, not to do them by hand. Steps marked
**[MANUAL]** have no automation path and must be done by hand.

Check each box as you go. Do not skip ahead — some steps gate others.

---

## Before the Machine Arrives (Pre-flight)

Run on your OLD machine. These gate everything else.

- [ ] Grant Terminal Full Disk Access (for Mail signatures):
      System Settings > Privacy & Security > Full Disk Access > + Terminal
- [ ] Run `scripts/preflight.sh` and resolve all warnings
- [ ] Review private configs in iCloud — any apps missing from the playbook?
- [ ] Fill in account assignments in `dotfiles-private/mail/signatures.md`
- [ ] Export Termius keys via Termius UI > Preferences > Keychain → save to 1Password
- [ ] iTerm2: Settings > General > Preferences > "Save Current Settings to Folder"
- [ ] iStat Menus: menu bar icon > Preferences > Export Settings → save to `dotfiles-private/istat/`
- [ ] Set config freeze date in `DECISIONS.md`
- [ ] `git add . && git commit -m "preflight capture" && git push`

---

## Stage 1: First Boot & Foundation (~45 min)

### macOS Setup Assistant
- [ ] **[MANUAL]** Complete setup assistant (language, region, Apple ID)
- [ ] **[MANUAL]** Sign into iCloud — private configs sync automatically in the background
- [ ] **[MANUAL]** Do NOT enable iCloud Desktop & Documents yet (enable in Stage 7)
- [ ] **[MANUAL]** Do NOT migrate from old Mac

### Bootstrap

Run bootstrap — installs Xcode CLI tools, clones this repo, updates macOS, and installs Ansible. Enter your password once, then walk away:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/dotfiles/main/scripts/bootstrap.sh)"
```

If bootstrap reports a restart is required for OS updates, restart then re-run the same command.

If curl fails, install Xcode CLI tools first (there's no git otherwise), then download and run bootstrap manually:

```bash
xcode-select --install
# Wait for the Install dialog, click Install, wait for it to finish.
# Then download bootstrap.sh from github.com/beauwoods/dotfiles and run:
bash ~/Downloads/bootstrap.sh
```

- [ ] **[VERIFY]** Bootstrap completed without errors
- [ ] **[VERIFY]** Dotfiles cloned to `~/Documents/GitHub/dotfiles`
- [ ] **[VERIFY]** Ansible found: bootstrap prints the path and version at the end

---

## Stage 2: First Ansible Run — Apps & Defaults (~45 min, unattended)

No auth required. Start it and walk away.

```bash
cd ~/Documents/GitHub/dotfiles/ansible
ansible-playbook main.yml -i inventory/localhost --ask-become-pass --tags apps,defaults
```

Installs all direct-download apps and applies all system settings (trackpad, scroll,
clock, sounds, Finder, Mail, iTerm2). App Store apps run in Stage 4 after auth.

- [ ] Run completed with no failed tasks
- [ ] Note any failed tasks here: ___________________

---

## Stage 3: Auth Session (~30 min)

Complete all logins before Stage 4. These gate the App Store installs.

- [ ] **[MANUAL]** App Store — sign in *(gates: all mas installs)*
- [ ] **[MANUAL]** 1Password — open app, sign into account
- [ ] **[MANUAL]** Adobe Creative Cloud — sign in as Nuri *(gates: Acrobat, PS, LR)*
- [ ] **[MANUAL]** SetApp — sign in *(gates: Paste, CleanMyMac, Timing, iStat Menus)*
- [ ] **[MANUAL]** Little Snitch — enter license key *(retrieve from 1Password)*

Defer until after Stage 4: Tailscale, Backblaze, Google Drive, Slack, Discord,
Teams, Zoom, Chrome sync, Microsoft 365 activation.

---

## Stage 4: Second Ansible Run — App Store & Config (~30 min, mostly unattended)

```bash
cd ~/Documents/GitHub/dotfiles/ansible
ansible-playbook main.yml -i inventory/localhost --ask-become-pass --tags mas,config
```

Installs all App Store apps and deploys per-app configs (SSH config, dotfiles,
Firefox policies, Little Snitch rule subscriptions).

- [ ] Run completed with no failed tasks
- [ ] Note any failed tasks here: ___________________

---

## Stage 5: Verify Automated Configuration

### System Settings — Trackpad
- [ ] **[VERIFY]** Point & Click: "Tap to click" is ON
- [ ] **[VERIFY]** Scroll & Zoom: "Natural scrolling" is OFF

### System Settings — General
- [ ] **[VERIFY]** Date & Time: Clock shows 24-hour format (e.g. 14:30 not 2:30 PM)
- [ ] **[VERIFY]** Language & Region: Temperature shows Celsius

### System Settings — Sound
- [ ] **[VERIFY]** Sound Effects: UI sound effects are OFF
- [ ] **[VERIFY]** Sound Effects: Alert sound is "Tink"

### Finder
- [ ] **[VERIFY]** File extensions visible (e.g. "report.docx" not "report")
- [ ] **[VERIFY]** Hidden files visible, path bar and status bar showing
- [ ] **[VERIFY]** Default view is List view

### Mail
- [ ] **[VERIFY]** Mail > Settings > Viewing: "Load remote content in messages" is OFF
- [ ] **[VERIFY]** Mail > Settings > Viewing: "Move discarded messages to" shows Archive

### Firefox
- [ ] **[VERIFY]** Open `about:policies` — all entries show green checkmarks
- [ ] **[VERIFY]** Extensions: NoScript is installed and enabled
- [ ] **[VERIFY]** Settings > Privacy: Strict tracking protection is on
- [ ] **[VERIFY]** Settings > Privacy: "Always use private browsing mode" is on
- [ ] **[VERIFY]** Settings > Privacy: "Ask to save logins" is off
- [ ] **[VERIFY]** Settings > General: "Always check if Firefox is your default browser" is off
- [ ] **[VERIFY]** HTTPS-Only Mode is enabled

### Little Snitch
- [ ] **[VERIFY]** Network Monitor shows all 6 rule group subscriptions loaded
- [ ] **[VERIFY]** Alert Detail shows "Port and Protocol Details"

### iTerm2
- [ ] **[VERIFY]** Settings > General > Preferences: custom folder points to iCloud private `iterm2/`
- [ ] **[VERIFY]** Profile and color scheme loaded correctly
- [ ] **[MANUAL]** If profile didn't load: click "Save Current Settings to Folder", restart iTerm2

---

## Stage 6: Post-Ansible Manual Steps

### System Preferences
- [ ] **[MANUAL]** Security & Privacy: Enable Apple Watch unlock
- [ ] **[MANUAL]** Internet Accounts: Add each account (Mail, Calendar, Contacts)
- [ ] **[MANUAL]** Keyboard: Remap Caps Lock to Escape (System Settings > Keyboard > Key Mappings)
- [ ] **[MANUAL]** Keyboard: Set Key Repeat to Fast, Delay Until Repeat to Short

### Mail
- [ ] **[MANUAL]** Add signatures from `dotfiles-private/mail/signatures.md`:
      open Mail > Settings > Signatures, click + for each, paste content, assign to account

### Browsers
- [ ] **[MANUAL]** Chrome: sign in, enable sync
- [ ] **[MANUAL]** 1Password: install browser extensions for Safari, Firefox, Chrome

### Microsoft 365
- [ ] **[MANUAL]** Open Word (or any Office app) and sign into M365 to activate
      (one sign-in activates all five apps)
- [ ] **[MANUAL]** Windows App (Remote Desktop): configure connections

### Adobe Creative Cloud
- [ ] **[MANUAL]** Open CC app (logged in as Nuri from Stage 3)
- [ ] **[MANUAL]** Install: Acrobat, Photoshop, Lightroom

### SetApp
- [ ] **[MANUAL]** Open SetApp (logged in from Stage 3)
- [ ] **[MANUAL]** Install: Paste, CleanMyMac, Timing, iStat Menus

### iStat Menus
- [ ] **[MANUAL]** Import settings — open `dotfiles-private/istat/iStatMenusSettings.ismp`

### SSH Keys

SSH keys should be freshly generated on the new machine — one key per device means
you can revoke precisely if a machine is lost.

- [ ] **[MANUAL]** Enable 1Password SSH agent: 1Password > Settings > Developer > "Use the SSH agent"
- [ ] **[VERIFY]** `~/.ssh/config` has IdentityAgent line: run `cat ~/.ssh/config`
- [ ] **[MANUAL]** Generate a new key — in Terminal:

```bash
ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y-%m)"
```

- [ ] **[MANUAL]** Store private key in 1Password: New Item > SSH Key > import `~/.ssh/id_ed25519`
- [ ] **[MANUAL]** Delete key file from disk (1Password agent serves it):

```bash
rm ~/.ssh/id_ed25519
# Keep ~/.ssh/id_ed25519.pub — it's public
```

- [ ] **[MANUAL]** Add public key to GitHub: Settings > SSH Keys > New SSH key
- [ ] **[MANUAL]** Add public key to any VPS/lab machines
- [ ] **[MANUAL]** Test: `ssh-add -l` and `ssh -T git@github.com`
- [ ] **[MANUAL]** Switch dotfiles remote to SSH:

```bash
git remote set-url origin git@github.com:beauwoods/dotfiles.git
```

- [ ] **[MANUAL]** Configure Termius: Preferences > Keychain > Use SSH agent
- [ ] **[MANUAL]** Revoke old machine's key from each service when done

### Remaining Account Logins
- [ ] **[MANUAL]** Tailscale — open app, authenticate via browser
- [ ] **[MANUAL]** Backblaze — sign in, configure backup folders and schedule
- [ ] **[MANUAL]** Google Drive — sign in, configure sync folders
- [ ] **[MANUAL]** Slack — sign into all workspaces
- [ ] **[MANUAL]** Discord — sign in
- [ ] **[MANUAL]** Microsoft Teams — sign in
- [ ] **[MANUAL]** Zoom — sign in

### Logitech
- [ ] **[MANUAL]** If Logitech Options+ is installed: disable Logi Flow in preferences
      (Flow hammers Tailscale IPs ~28k/week; Little Snitch denies it but kill it at source)

### Privacy Permissions

Grant these in System Settings > Privacy & Security proactively.

- [ ] **[MANUAL]** Full Disk Access: Backblaze, iTerm2
- [ ] **[MANUAL]** Screen Recording: Zoom, Microsoft Teams
- [ ] **[MANUAL]** Accessibility: Magnet (prompts on first use)
- [ ] **[MANUAL]** Network Extension: Little Snitch (prompted on first launch)
- [ ] **[MANUAL]** Wireshark packet capture — in Terminal:

```bash
sudo dseditgroup -o edit -a $(whoami) -t user access_bpf
```

---

## Stage 7: Final Steps

- [ ] **[MANUAL]** iCloud: enable Desktop & Documents — System Settings > Apple ID > iCloud Drive
- [ ] Restart Mac
- [ ] Smoke test:
  - [ ] Finder shows file extensions, hidden files, path bar
  - [ ] Clock shows 24-hour format, temperature in Celsius
  - [ ] UI sounds off, alert sound is Tink
  - [ ] Scroll direction is correct (non-natural)
  - [ ] Click-to-show Desktop is disabled (click desktop — windows should NOT hide)
  - [ ] Browser extensions working in Safari, Firefox, Chrome
  - [ ] 1Password prompting in all three browsers
  - [ ] Tailscale connects
  - [ ] Backblaze backup initializing
  - [ ] Little Snitch alerting (test by opening a new app)
  - [ ] iTerm2 profile looks correct
  - [ ] iStat Menus visible in menu bar
  - [ ] Magnet window snapping works
  - [ ] `ssh -T git@github.com` works after restart
- [ ] `git add . && git commit -m "post-deployment notes" && git push`

---

## Notes / Issues Encountered

*Fill in on deployment day.*

---

## Time Estimate

| Stage | Estimated time |
|---|---|
| Pre-flight (before machine arrives) | 2-3 hours |
| Stage 1: First boot + bootstrap | 45 min |
| Stage 2: Apps & defaults (unattended) | 45 min |
| Stage 3: Auth session | 30 min |
| Stage 4: App Store & config (unattended) | 30 min |
| Stage 5: Verify automated config | 20 min |
| Stage 6: Manual steps | 60-90 min |
| Stage 7: Final steps + smoke test | 30 min |
| **Total on deployment day** | **~3.5-4.5 hours** |
