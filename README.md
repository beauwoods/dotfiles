# mac-config

Beau's Mac setup. One command, deterministic, repeatable.

Built on [geerlingguy/mac-dev-playbook](https://github.com/geerlingguy/mac-dev-playbook)
with iCloud Drive for private data. This repo contains zero secrets.

## Architecture

Three components:

- **Geerling's playbook** — cloned at bootstrap time, never forked
- **iCloud Drive** (`dotfiles-private/`) — syncs automatically once you sign
  into Apple ID; holds shell dotfiles, SSH config, iTerm2 prefs, signatures
- **This repo** — holds `config.yml`, custom task files, Firefox policy,
  bootstrap scripts

## Quick Start (new machine)

Complete macOS Setup Assistant and sign into Apple ID first, then:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/beauwoods/mac-config/main/scripts/bootstrap.sh)"
```

This runs in two phases:

1. **Phase 1 (~2 hours, unattended)** — Xcode CLI tools, Homebrew, Ansible,
   all packages/casks/App Store apps, macOS preferences, Dock layout
2. **Pause** — a window opens with manual steps (Adobe CC sign-in, SetApp,
   Little Snitch license, 1Password SSH agent)
3. **Phase 2 (~5 min)** — SSH config restore, Firefox policy, Little Snitch
   prefs, Dock folders, Timing added to Dock

## Preflight (on the old machine)

Before deployment day, capture private configs to iCloud:

```bash
~/mac-config/scripts/preflight.sh
```

This copies shell dotfiles, SSH config, mail signatures, iTerm2/iStat prefs,
and a defaults snapshot to `~/Library/Mobile Documents/com~apple~CloudDocs/dotfiles-private/`.
Everything syncs to the new machine via iCloud.

## Repo Layout

```
mac-config/                          (this repo)
├── README.md
├── config.yml                       ← overrides Geerling's default.config.yml
├── requirements.yml                 ← Ansible Galaxy dependencies
├── scripts/
│   ├── bootstrap.sh                 ← curl-able one-command setup
│   └── preflight.sh                 ← run on old machine before deployment
├── tasks/
│   ├── extra-packages.yml           ← dispatcher (Geerling imports this)
│   ├── osx-defaults.yml             ← all macOS preferences
│   ├── remove-bundled-apps.yml      ← removes GarageBand, iMovie, etc.
│   ├── firefox-policy.yml           ← deploys policies.json
│   ├── little-snitch.yml            ← write-preference commands
│   ├── ssh-config.yml               ← restores SSH + dotfiles from iCloud
│   └── dock-folders.yml             ← adds Timing, Desktop, Downloads to Dock
├── configs/
│   └── firefox/
│       └── policies.json            ← Firefox enterprise policy
└── docs/
    └── MANUAL_PAUSE.md              ← steps shown during the pause

dotfiles-private/                    (iCloud Drive, never in this repo)
├── ssh/config
├── shell/                           ← .zshrc, .gitconfig, etc.
├── iterm2/                          ← iTerm2 profile
├── istat/                           ← iStat Menus preferences
└── mail/signatures.md
```

## How It Works

Bootstrap clones Geerling's playbook and symlinks our `config.yml` and
individual task files into it. Geerling's `main.yml` loads our config
(overriding his defaults) and imports our `tasks/extra-packages.yml`
(which dispatches to our custom task files).

Phase separation uses Ansible tags:
- `--skip-tags post-auth` runs everything except post-auth tasks
- `--tags post-auth` runs only the tasks that need manual setup first

## Re-running

From `~/mac-dev-playbook`:

```bash
# Full Phase 1 again
ansible-playbook main.yml --ask-become-pass --skip-tags post-auth

# Full Phase 2 again
ansible-playbook main.yml --ask-become-pass --tags post-auth

# Just macOS defaults
ansible-playbook main.yml --ask-become-pass --tags extra-packages --skip-tags post-auth

# Just Dock
ansible-playbook main.yml --ask-become-pass --tags dock
```

## SSH Keys (post-bootstrap)

Not automated — inherently interactive and one-per-machine:

```bash
ssh-keygen -t ed25519 -C "$(hostname)-$(date +%Y-%m)"
# Store private key in 1Password → New Item → SSH Key → import ~/.ssh/id_ed25519
rm ~/.ssh/id_ed25519
# Add ~/.ssh/id_ed25519.pub to GitHub Settings → SSH Keys
ssh -T git@github.com
git -C ~/mac-config remote set-url origin git@github.com:beauwoods/mac-config.git
```

## What's Automated

| Area | How |
|---|---|
| CLI tools | Homebrew packages via Geerling's homebrew role |
| GUI apps | Homebrew casks via Geerling's homebrew role |
| App Store apps | `mas` CLI via Geerling's mas role |
| Dock layout | Geerling's dock role + `dock-folders.yml` |
| macOS preferences | `osx_defaults` module in `osx-defaults.yml` |
| Shell dotfiles | Copied from iCloud private via `ssh-config.yml` |
| SSH config | Copied from iCloud private via `ssh-config.yml` |
| Firefox policy | `policies.json` deployed to `/Library/Application Support/Mozilla/` |
| Little Snitch | `littlesnitch write-preference` commands |
| iTerm2 | `PrefsCustomFolder` pointed at iCloud private |
| Bundled app removal | GarageBand, iMovie, Pages, Numbers, Keynote |

## Logs

Every bootstrap run writes a timestamped log:

```
~/.local/share/mac-setup/logs/ansible_YYYYMMDD_HHMMSS.log
```
