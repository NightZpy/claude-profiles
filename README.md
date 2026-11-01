# Claude Profiles

A small macOS menu bar app to run several Claude Desktop accounts side by side, for
example a work account and a personal one.

Out of the box there is a single profile, **Main**: your regular Claude Desktop.
Every profile you add runs as its own Claude Desktop window with its own login, settings
and Claude Code configuration, and they all stay open at the same time.

From the menu bar icon you can:

- open a profile, or jump to its window if it is already running
- create a new profile
- reveal a profile's data folder in Finder, or delete the profile (right click, or the trash icon on hover)
- start the app at login

## Install

Requirements: macOS 14 or later, [Claude Desktop](https://claude.ai/download) in
`/Applications`, and the Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/NightZpy/claude-profiles.git
cd claude-profiles
./run.sh
```

`run.sh` compiles the app, installs it in `~/Applications/Claude Profiles.app` and opens
it. Look for its icon in the menu bar.

## Signing in to a new profile

When other profiles are already open, sign in like this:

1. In the new profile's window choose **Continue with email**, not Google.
2. When it asks how to sign in, pick the option to use a code.
3. Open the link Anthropic emails you in your browser.
4. If the browser offers to open the Claude app, decline it and choose to sign in with a
   code instead. You land on a page that shows the code.
5. Type that code into the new profile's window.

Google sign-in and the "open Claude" button both finish through a `claude://` link, and
macOS sends that link to the Claude window that started first, so it never reaches the
new profile.

## How it works

A profile named `Work` is the folder `~/Library/Application Support/Claude-Work`. Inside
it, `.claude-config-dir` holds the Claude Code config folder that profile uses (by default
`~/.claude-work`). Opening it runs:

```sh
open -n -a Claude --env CLAUDE_CONFIG_DIR=~/.claude-work \
  --args --user-data-dir="$HOME/Library/Application Support/Claude-Work"
```

`--user-data-dir` gives the instance its own login and data. Signed Claude builds ignore
the `CLAUDE_USER_DATA_DIR` variable but honor this switch. `CLAUDE_CONFIG_DIR` makes the
Claude Code sessions inside that window use their own settings, skills and history.

Notes:

- All profiles share the same `Claude.app`, so when Claude updates itself the extra
  windows may close. Reopen them from the menu bar.
- Clicking Claude in the Dock always focuses an instance that is already running. To open
  Main while another profile is running, use the menu bar app.

To remove a profile, right click it and choose **Delete profile…**. It quits that window
and moves the profile folder to the Trash, and optionally its Claude Code folder too.

## Icon

The icon source is [`assets/icon.svg`](assets/icon.svg). `assets/AppIcon.icns` is the
macOS build of it.

## Disclaimer

Unofficial project, not affiliated with or endorsed by Anthropic. It only launches the
Claude Desktop app you already have installed.

## License

Public domain ([Unlicense](LICENSE)).
