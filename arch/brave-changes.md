# Brave Flatpak - Sandbox Fix

## Problem

Brave (Flatpak) tabs crash with "Error 5" on kernel 6.19.11+. The Chromium sandbox/zygote
process model is incompatible with changes in the 6.19 kernel series.

Key errors in logs:

- `Failed global descriptor lookup: 7` (shared memory)
- `ptrace: Operation not permitted` (crashpad)
- `prctl: Invalid argument` (crashpad)

## Fix

Created `~/.var/app/com.brave.Browser/config/brave-flags.conf`:

```
--no-zygote
--no-sandbox
```

Brave reads this file automatically at startup.

## Notes

- `--no-sandbox` disables the Chromium renderer sandbox — this is a security trade-off.
- Periodically try removing these flags after running `flatpak update` to see if the issue
  has been resolved upstream by Brave/Chromium or the Flatpak runtime.
- GPU was not disabled in the permanent config; only used `--disable-gpu` during debugging.

## Date

2026-04-09

Reverted : 2026-04-14 after upstream fix
