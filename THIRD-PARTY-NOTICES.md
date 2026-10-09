# Third-party notices

MacCare itself is MIT licensed (see `LICENSE`). It relies on the following.

## mo (Mole) — runtime dependency, not included

- Project: <https://github.com/tw93/Mole> by tw93
- License: **GNU General Public License v3.0**
- How MacCare uses it: it runs the user's own installed `mo` command as a **separate process** (command-line
  arguments, stdin/stdout text and JSON). `mo` is **not** bundled in the app, the DMG or this repository, and no `mo`
  source code is copied or linked into MacCare. Users install it themselves (`brew install mole`).
- If you ever redistribute `mo` together with MacCare, the GPL-3.0 applies to that copy of `mo` and you must meet its
  terms (provide the licence and corresponding source).
- MacCare is an independent project. It is **not** affiliated with, endorsed by, or derived from tw93 or the paid
  "Mole for Mac" application. No Mole for Mac code, artwork, icons, text or other assets were used.
  "Mole" is the name of that project; MacCare does not use it as its own name.

## Design mockups

The first design explorations used [Phosphor Icons](https://phosphoricons.com) (MIT, © Phosphor Icons). The app
itself uses Apple's SF Symbols for in-app glyphs, as permitted for apps running on Apple platforms. The app icon is
original artwork drawn by `Tools/make-icon.swift` and uses no SF Symbols.

## Fonts

MacCare uses the system fonts (SF Pro and SF Mono). No font files are bundled.

## cleanX

The Xcode page's item list and explanations are ported from the author's own MIT-licensed
[cleanX](https://github.com/hlum/cleanX) script.
