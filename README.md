# Claude Profiles

A small macOS menu bar app to run several Claude Desktop accounts side by side, for
example a work account and a personal one.

Out of the box there is a single profile, **Main**: your regular Claude Desktop.
Every profile you add runs as its own Claude Desktop window with its own login, settings
and Claude Code configuration, and they all stay open at the same time.

From the menu bar icon you can:

- open a profile, or jump to its window if it is already running
- create a new profile
- reveal a profile's data folder in Finder (right click)
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
it. Look for its icon in the menu bar. The app icon is generated from the Claude Desktop
icon already on your Mac, so no Claude artwork is shipped in this repo.

## Signing in to a new profile

Use **Continue with email** and type the code you receive. Google sign-in finishes
through a `claude://` link, and macOS sends that link to the Claude window that started
first, so it never reaches the new profile.

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

To remove a profile, quit it and delete its `Claude-<Name>` folder.

## Disclaimer

Unofficial project, not affiliated with or endorsed by Anthropic. It only launches the
Claude Desktop app you already have installed.

## License

Public domain ([Unlicense](LICENSE)).
