# Agent Notes

This is a personal sysadmin scripts repo. All code is shell scripts for installing, maintaining, and troubleshooting Linux workstations (Arch, Void, Debian).

## Verification

The only automated check is **ShellCheck**:

```bash
# Exact CI command (only these directories are checked)
shellcheck -s bash kickstart/* maintenance/*
```

`troubleshooting/` is **not** checked by CI.

## Safety

- Many scripts require `root`/`sudo` and mutate real system state.
- `kickstart/install-*.sh` partition disks, enable LUKS encryption, and install bootloaders — they are **destructive**.
- `maintenance/update-*.sh` run live system updates.
- Never execute these against the current host without explicit user confirmation.

## Script Organization

| Directory | Purpose |
|-----------|---------|
| `kickstart/` | OS installation & initial environment setup (dwm, slstatus, dotfiles) |
| `maintenance/` | Routine system updates and package cleanup |
| `troubleshooting/` | Ad-hoc one-off fixes |

## Architecture Notes

- `install-dwm.sh` **sources** `kickstart-void.sh` via `--source-only` to reuse its `install_dwm()` function. Do not remove that flag or refactor without updating the caller.
- Kickstart scripts are **interactive**: they use a `confirm()` helper that defaults to *no* and prompts for optional components (Docker, Bluetooth, Flatpak apps, etc.).
- `kickstart-*.sh` clones external repos (`danguita/dotfiles`, `danguita/dwm`, `danguita/slstatus`) and runs `make install` / `make deploy` on them.
- Scripts use either `#!/usr/bin/env bash` (with `set -e`) or `#!/usr/bin/env sh` (maintenance scripts).

## Style

- Use `say()` for user-facing log output: `printf "\n[$(date --iso-8601=seconds)] %s\n" "$1"`
- Use `shellcheck disable=SC2317` for functions that appear unused due to dynamic/conditional invocation.

## Consistency

- Keep `kickstart-arch.sh` and `kickstart-void.sh` in parity. Adding a package, service, hardware prompt, or `confirm()` block to one generally means adding it to the other.
- Use `|| true` (or fallback chains) for desktop commands (`xdg-settings`, `dconf`) so `set -e` does not abort in headless sessions.

## Commit Style

Prefix with `(scope)` and keep the subject line imperative:

```
(kickstart-arch) Add NVIDIA GPU support
(install-void) Auto-detect NVMe partitions
(maintenance) Clean package cache
```
