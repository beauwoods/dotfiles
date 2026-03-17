# Pause Here — Complete These Steps

Bootstrap has finished installing all apps. Complete the items below,
then return to the terminal and press Enter to continue.

---

## 1. Full Disk Access for Terminal (~1 min)
Required for Phase 2 to write Mail.app preferences (macOS Tahoe sandbox).

System Settings > Privacy & Security > Full Disk Access → enable **Terminal**.

## 2. Adobe Creative Cloud (~5 min)
Open Adobe Creative Cloud → sign in → install Acrobat, Photoshop, Lightroom.

## 3. SetApp (~3 min)
Open SetApp → sign in → install: Paste, CleanMyMac, Timing, iStat Menus.

## 4. Little Snitch (~5 min)
- Open Little Snitch → enter license key (1Password: Little Snitch License)
- Settings > Security → enable "Allow access via Terminal"
- Rule Groups sidebar > + > Subscribe to Rule Group (add each URL):
  - https://frabjous-cucurucho-6b35d1.netlify.app/core_os_networking_security.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/misc_apps.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/apple_apps.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/adobe.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/browsers.lsrules
  - https://frabjous-cucurucho-6b35d1.netlify.app/microsoft_google.lsrules

## 5. 1Password (~2 min)
Open 1Password → sign in → Settings > Developer → enable "Use the SSH agent".

## 6. Trackpad Scroll Direction
System Settings > Trackpad > Scroll & Zoom → turn off "Natural Scrolling".
(The `defaults write` for this setting does not persist through reboot on macOS Tahoe —
toggle it here so macOS syncs it properly.)

## 7. Launch Mail (~30 sec)
Open Mail.app and add your account(s). Phase 2 will write Mail preferences
automatically via `defaults write` (requires Full Disk Access from step 1).

---

When all done, return to the terminal and press Enter.
