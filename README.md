# vvb-projects-agent

Multi-host project hygiene tool for **Vi Vet Bil AB**. Runs on Linux, watches your `~/Projects` directory, syncs your GitHub repos, scans for leaked secrets, validates repo structure, and emits NTFY/Telegram alerts.

Primary controller: **calm-narwhal** (Hostup VPS). 3 additional Linux hosts run the same binary; reports consolidate.

## What it does (v0.1)

| Subcommand | Action | Read/Write |
|---|---|---|
| `sync` | git fetch + `ff-only` merge of origin/HEAD on every tracked repo | writes local history |
| `scan` | Walk every file in every repo, run 12 secret patterns (AWS, GitHub, OpenAI, Anthropic, Slack, Stripe, SendGrid, JWT, private keys, ...) | read-only |
| `structure` | Detect missing `CLAUDE.md`, thin README, empty dirs, duplicate clones | read-only |
| `fix` | Apply **safe-only** auto-fixes from `auto_fix.*` flags in config | writes (safe subset) |
| `report` | One-shot summary → stdout + NTFY + Telegram | side-effects only on channels |
| `watch` | Long-running loop that calls `report` every `watch_interval_sec` | continuous |
| `config show/validate` | Dump config / fail-fast on missing keys | read-only |

**Breaking actions (`force-push`, `branch-delete`, `secret-redact`) are off by default** and require `auto_fix.breaking: true` in `config.yaml`. Nothing destructive runs without an explicit config flag — see [Features explicitly listed](#features-explicitly-listed) in `config.yaml`.

## Install (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/vvb-1/vvb-projects-agent/main/install.sh | bash
```

Idempotent. Installs:
- `${HOME}/.local/share/vvb-projects/` — source (clone of this repo)
- `${HOME}/.local/bin/vvb-projects` — symlink to the binary
- `${HOME}/.config/vvb-projects/config.yaml` — seeded from `config.yaml`, never overwritten
- crontab line: `15 9 * * * vvb-projects report`

## Install (Windows) — v2

Windows support is **deliberately deferred** until the Linux version is stable. Plan:
- `install.ps1` — PowerShell wrapper
- `README-WINDOWS.md` — operator instructions
- Windows hosts only get *pushed reports* (no local scan).

## Manual use

```bash
vvb-projects sync                         # update every clone
vvb-projects scan                         # audit for leaked secrets
vvb-projects structure                    # find missing CLAUDE.md / thin README / empty dirs
vvb-projects fix                          # prune empty dirs (safe-only)
vvb-projects report                       # one-shot report → NTFY/Telegram
vvb-projects watch                        # loop forever
vvb-projects --config /path/to/config.yaml scan
```

## Channels

Default: **NTFY**. Topic is auto-generated on first run as `vvb-projects-<sha256-of-hostname[:8]>`. Subscribe from your phone with the NTFY app.

Telegram fallback: set `channels.telegram.enabled: true`, `chat_id`, and `bot_token_env` (env var holding your bot token).

## Dependencies

- `python3` (stdlib only)
- `git`
- `gh` (optional — enables GitHub org auto-discovery; falls back to local clones only)

No pip packages. No Docker. No systemd.

## Scope reminder

Read **EVERY** flag in `config.yaml` before flipping it. The whole point of this tool is to keep your repos tidy — turning on the wrong flag turns it into a deletion machine.

## License

Internal. Vi Vet Bil AB.