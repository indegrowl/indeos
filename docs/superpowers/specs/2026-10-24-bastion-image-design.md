# bastion — Bazzite + Hyprland image design

Date: 2026-10-24
Repo: `github.com/indegrowl/indeos` (BlueBuild)

## Intent

`bastion` is the owner's always-on desktop (AMD Ryzen with iGPU + Radeon RX 9070). It does three jobs:

1. **Gaming**, mostly streamed to a Nothing Phone (4a), occasionally played on bastion's own monitor.
2. **Coding**, often remotely from a laptop over SSH into tmux (possibly zellij later).
3. **Media server** (arr stack), which will be moved to Podman containers as a later, separate project.

It currently runs Omarchy (Arch). The goal is a Bazzite-based, Hyprland desktop image built with BlueBuild, so the gaming stack is solid, updates are atomic and rollback-able, and everything the machine depends on is declared in this repo.

## Goals

- Bazzite base with Hyprland as the only desktop.
- Boots straight into Hyprland with no visible login screen.
- Reachable over SSH via Tailscale immediately after any reboot, before anyone logs in.
- Never suspends; the monitor still blanks when idle.
- Game streaming via both Steam Remote Play and Sunshine/Moonlight.
- Dev workstation: mise, rustup, AI coding agents (Hermes, pi), a curated CLI toolset.
- chezmoi pre-installed and linked to `github.com/indegrowl/dotfiles` (via BlueBuild's chezmoi module).
- **Every package bastion depends on is declared explicitly in the config, even if Bazzite already ships it.** If Bazzite drops something, the build either installs it or fails loudly.

## Non-goals

- The `indeos-remote` recipe / laptop image. Leave it untouched.
- The arr stack (Jellyfin, Sonarr, Radarr, Prowlarr, Seerr, FlareSolverr, qBittorrent, Surfshark). Later project. The image only needs Podman.
- Steam console/gaming mode session (no `bazzite-deck`).
- Writing the actual desktop config (Hyprland look, bar, keybindings). That is the dotfiles project, done after the image boots.
- Final headless streaming wiring (see §2): done after first boot, lands in dotfiles.

## Anti-goals

- A visible display manager the owner has to interact with on a normal boot.
- The machine ever going to sleep on its own, or auto-rebooting for updates.
- Secrets committed to the dotfiles repo.
- Silent reliance on a package that only happens to be in the base image.

## Constraints

- BlueBuild, GitHub Actions (`.github/workflows/build.yml`), cosign-signed image (keep the `signing` module).
- AMD GPU only: use the standard Bazzite image, not `-nvidia`.
- Image is single-machine, so machine identity (hostname) may live in the image.

---

## 1. Base & desktop

- **Recipe:** new `recipes/bastion.yml`, image `name: bastion`, replacing `recipes/indeos.yml` (delete it; update the workflow matrix from `indeos.yml` to `bastion.yml`, keep `indeos-remote.yml` as is).
- **Base:** `ghcr.io/ublue-os/bazzite`, tag `stable`. *(Builder's call on tag if `stable` is not the right channel.)*
- **Remove:** KDE Plasma and SDDM (owner's decision). Keep **Dolphin**, declared explicitly, as the graphical file manager. Builder must make sure Dolphin still works outside Plasma (e.g. "Open with" menus need a menu file/`XDG_MENU_PREFIX`). Removal scope (Claude's call): remove the Plasma shell/session, SDDM and KDE apps (Konsole, Kate, Gwenview, Discover, etc.); keep KIO and KWallet so Dolphin and Chromium secret storage keep working.
- **Hyprland:** from a maintained Fedora COPR (builder picks the one that's current for the Bazzite Fedora version). Install: hyprland, hyprlock, hypridle, hyprpaper, xdg-desktop-portal-hyprland, xdg-desktop-portal-gtk, uwsm, qt5/qt6-wayland, polkit agent. Bar/launcher/notification daemon: **builder picks sensible defaults** and installs them; configuration belongs to dotfiles.
- **Login:** **greetd**.
  - `initial_session` autologs the owner's user into Hyprland via `uwsm start hyprland.desktop`, so no screen is shown on boot. This lives in `/etc/greetd/config.toml` in the image, so it works with an empty dotfiles repo.
  - `default_session` is **tuigreet**, shown only if the session exits/crashes.
  - The autologin username must be the owner's user, `indegrowl`. *(Builder: since users are created at install time, confirm the user is named `indegrowl` at install, or template it.)*
- **Lock after login:** optional, via hyprlock from dotfiles.
- **Lingering:** enable lingering for `indegrowl` so user services (streaming, future Podman containers) start at boot without a session.
- **Module:** `modules/desktop.yml`.

## 2. Gaming & streaming

- **Hardware facts (checked on bastion):** the monitor is on the RX 9070 (`0000:03:00.0`, DP-3); the iGPU has nothing connected. Secure Boot is currently disabled, so no key enrollment step is needed unless the owner turns it on.

- **In the image** (`modules/gaming.yml`, all declared explicitly): steam, gamescope, mesa/vulkan-radeon packages, **sunshine** (Bazzite ships it; declare it anyway, add from its repo if missing).
- **Firewall:** open Steam Remote Play and Sunshine ports (on the LAN zone; Tailscale interface is trusted anyway, §3).
- **After first boot (not in the image):** set up a headless gamescope session running Steam Big Picture sized for the phone, decide how streamed and local play share one Steam instance, pair Moonlight, tune. Resulting systemd user units go in dotfiles. A quick throwaway spike validates that headless gamescope + Steam works with both Steam Remote Play and Sunshine.
- **Local play:** Steam on the Hyprland desktop as usual.

## 3. Remote access & always-on

`modules/remote.yml`:

- **SSH (owner's decision): reachable only through Tailscale, and there it accepts password login. Root login is off everywhere (owner uses sudo).**
  - openssh-server, `sshd` enabled at boot.
  - Firewall: SSH is **not** open on the LAN zone; it's reachable only via the trusted `tailscale0` interface.
  - sshd itself also enforces it (defense in depth, Claude's call): global `PasswordAuthentication no` / `PermitRootLogin no`, then a `Match Address 100.64.0.0/10,fd7a:115c:a1e0::/48` block that sets `PasswordAuthentication yes`. `PermitRootLogin no` applies everywhere. Keys work everywhere sshd is reachable.
  - Consequence: if Tailscale is down or not yet logged in, remote SSH is unavailable; use the local console. So `tailscale up` is the first post-install step.
- **Tailscale:** tailscale package, `tailscaled` enabled at boot. Owner runs `tailscale up` once after first boot. MagicDNS gives `bastion`.
- **mDNS:** avahi + nss-mdns so `bastion.local` resolves on the LAN.
- **Firewall:** firewalld on; `tailscale0` fully trusted (owner's decision); LAN zone allows only the streaming ports (no SSH).
- **Never sleep:** mask `sleep.target`, `suspend.target`, `hibernate.target`, `hybrid-sleep.target`. Screen blanking still happens via hypridle (lock ~10 min, DPMS off ~15 min, set in dotfiles).
- **Hostname:** `bastion`, set in the image.
- **Updates:** Bazzite/rpm-ostree auto-staging stays on; **never auto-reboot** (Claude's call). Make sure any Bazzite/uupd auto-update setting does not reboot.
- **Out of scope:** "power on after power loss" is a BIOS setting.

## 4. Dev tools & containers

- **`modules/dev-languages.yml`** (trimmed from current): rustup, mise, gcc, clang, mold, python3-devel, lua-devel. Remove golang, python/uv, nodejs, lua/luajit/luarocks: those come from mise per user.
- **`modules/ai-agents.yml`** (new, owner asked for a separate module): Hermes Agent = Nous Research `hermes-agent` (pipx/uv tool to a system path; same tool the owner runs today via mise `pipx:hermes-agent`), pi-agent = `@mariozechner/pi-coding-agent` (global npm package; the `pi` tool the owner runs today via mise). Updated by daily image rebuilds. **Claude Code is not in the image** (owner's decision: the image is public and Claude Code is proprietary); the owner installs it per user after first boot. A system nodejs stays in the image only as pi-agent's runtime (Claude's call).
- **`modules/cli-tools.yml`** (new): kitty (terminal; matches Hyprland's default Super+Q binding so the desktop works with empty dotfiles), chezmoi, neovim, tmux, zellij, git, lazygit, starship, gh, btop, glow, pass, gnupg2, zoxide, fzf, ripgrep, tree, yazi, wl-clipboard, cliphist.
- **`modules/containers.yml`** (new): podman, distrobox, podman-compose (Claude's call).
- **build123d support:** system libraries the OCP/OpenCascade wheels need (libGL/mesa-libGL, fontconfig, libX11/libXrender etc. — builder verifies by importing build123d in a uv venv on the built image). build123d itself is installed per project with uv + mise Python, not in the image. Viewer: `ocp_vscode` standalone (browser tab, live reload from nvim). Export to STL/3MF for Bambu Studio.

## 5. Desktop apps

`modules/apps.yml` (RPMs) + BlueBuild `default-flatpaks` module (Flathub, system):

| App | Source |
|---|---|
| Telegram | Flatpak `org.telegram.desktop` |
| Discord | Flatpak `com.discordapp.Discord` |
| Zulip | Flatpak `org.zulip.Zulip` |
| Chromium | Flatpak `org.chromium.Chromium` |
| OBS Studio | Flatpak `com.obsproject.Studio` (+ Bazzite's vkcapture plugin) |
| Bambu Studio | Flatpak `com.bambulab.BambuStudio` |
| qutebrowser | RPM (needs host access for userscripts like `qute-pass`) |
| Dolphin | RPM (kept from base, declared explicitly) |

**Chat TUIs** (`modules/chat.yml`): **nchat** (Telegram), **zulip-terminal** (Zulip). No Discord TUI (owner declined discordo). Install method (package/COPR/release binary/uv tool) is the builder's call.

**Font:** Cascadia Code Nerd Font (CaskaydiaCove NF), system-wide.

Everything else currently installed on Omarchy is intentionally left out; it can be added to a module later.

## 6. Dotfiles (chezmoi)

- Use BlueBuild's **`chezmoi` module** (owner's decision): `repository: https://github.com/indegrowl/dotfiles.git`, `all-users: true`, `disable-update: true`, `file-conflict-policy: skip`.
- Its `chezmoi-init.service` user unit runs `chezmoi init --apply` on first login (or at boot, with lingering) if `~/.local/share/chezmoi` doesn't exist. The clone lives in chezmoi's **default folder, `~/.local/share/chezmoi`** (owner accepted this over `~/projects/dotfiles`); reach it with `chezmoi cd`.
- chezmoi is still declared via dnf in `cli-tools.yml`; the module's own binary download is turned off if the module allows it, otherwise the dnf entry is dropped and the module provides it (builder's call).
- The repo is public and currently holds only `LICENSE`. Without a `.chezmoiignore`, chezmoi would copy `LICENSE` into `~`. A `.chezmoiignore` listing `LICENSE` and `README.md` is added to the dotfiles repo.
- After first boot, the owner switches the remote to SSH for pushing (Claude's call). No automatic `chezmoi update` (Claude's call).
- Filling the dotfiles is a separate project.

## 7. Installation & storage

- **Path:** install the stock Bazzite ISO (KDE, AMD) on `nvme1n1` (931G), wiping Omarchy and the old `/home`. Owner confirmed everything is backed up on the 2TB drive. Then rebase onto the `bastion` image (unsigned, reboot, then signed, as in the README).
- **User:** create `indegrowl` at install time. Keep UID/GID 1000 if the installer allows it, since files on the data drive are owned by UID 1000. greetd autologin and lingering hardcode `indegrowl`.
- **Data drive:** `nvme0n1p1` (1.8T btrfs, UUID `5ade185d-b4a7-4dfb-80d8-691830837386`) is kept untouched and **declared in the image** as a systemd `.mount` unit at `/mnt/data`, using UUID and `nofail` so a missing drive never blocks boot (Claude's call). It holds the backups now and will hold arr media later. The `media` group (GID 959 on Omarchy) isn't recreated now; that's for the arr project.
- **Secure Boot:** off today, so there's no enrollment step.
- **README:** replace the template text with these bastion install steps.

## Left to the builder

- Hyprland COPR choice; bar/launcher/notification defaults.
- Exact install method for each AI agent and chat TUI.
- Exact firewall port lists.
- How to declare already-present base packages without breaking the build.
- Base image tag.
- File layout under `files/system/` for greetd config, sshd drop-in, systemd units, hostname.
- Updating `README.md` to describe bastion.

## Claude's calls (for owner review)

sshd Match-block enforcement of the Tailscale-only rule; HTTPS-then-SSH dotfiles remote; no auto-reboot; no auto `chezmoi update`; podman-compose; cliphist; system nodejs for pi-agent; image named `bastion` in a new `bastion.yml`; Flatpak vs RPM per app.
