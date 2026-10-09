# Installing MacCare

MacCare needs **macOS 14 (Sonoma) or newer**. It is a front end for the free `mo` command, so there are two steps.

## 1. Install the engine (`mo`)

MacCare does the interface; the cleaning itself is done by [`mo`](https://github.com/tw93/Mole), which you install
with [Homebrew](https://brew.sh):

```sh
brew install mole
```

No Homebrew? Install it first from <https://brew.sh>. MacCare finds `mo` in `/opt/homebrew/bin` (Apple Silicon)
or `/usr/local/bin` (Intel). If it can't find it, the app shows this same instruction on screen.

## 2. Install MacCare

1. Download `MacCare-<version>.dmg` from the [latest release](https://github.com/hlum/MacCare/releases/latest).
2. Open the DMG and drag **MacCare** onto the **Applications** shortcut.
3. Eject the DMG, then open MacCare from Applications.

### "MacCare can't be opened" on first launch

MacCare is signed locally (ad-hoc) and **not notarized by Apple**, so macOS blocks the first launch.

**macOS 15 (Sequoia) and later**

1. Try to open MacCare once. When the warning appears, click **Done**.
2. Open **System Settings › Privacy & Security**, scroll to *Security*, and click **Open Anyway** next to MacCare.
3. Confirm with your password or Touch ID. You only do this once.

**Terminal alternative (any version)**

```sh
xattr -dr com.apple.quarantine /Applications/MacCare.app
```

On macOS 14, right-click the app and choose **Open** works too.

> Prefer not to trust a binary? Build it yourself: see *Build from source* in the [README](README.md).

## Start at login

Click the MacCare reading in the menu bar and switch on **Start at login**. MacCare then lives in the menu bar and
keeps the window closed. If macOS asks, allow it under **System Settings › General › Login Items**.

## Good to know

- Everything is previewed with a dry run first. Nothing is removed until you confirm.
- System-level caches need an administrator password; MacCare skips them rather than asking.
- Some app caches may need **Full Disk Access** to be seen (System Settings › Privacy & Security › Full Disk Access).
  It is optional.
- Closing the window keeps the menu bar item running. Use **Quit** in the menu bar popover to exit.

## Update

Download the newer DMG and drag MacCare over the old copy in Applications. To update the engine: `brew upgrade mole`.
MacCare was tested against `mo` **1.56.1**; a much newer or older `mo` may print something the app can't read.

## Uninstall

1. Switch off **Start at login** in the menu bar popover (or remove it in System Settings › General › Login Items).
2. Quit MacCare from the menu bar popover.
3. Drag `/Applications/MacCare.app` to the Trash.
4. Optional: `brew uninstall mole` if you no longer want the engine.
