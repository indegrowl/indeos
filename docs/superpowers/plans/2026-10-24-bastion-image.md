# bastion Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `indeos` BlueBuild recipe with a `bastion` image: Bazzite (AMD) + Hyprland, greetd autologin, Tailscale-only SSH, never-sleep, streaming, dev tools, apps, chezmoi bootstrap, and a declared data-drive mount.

**Architecture:** One recipe, `recipes/bastion.yml`, that pulls in one module-list file per spec section from `recipes/modules/`. Static config lives under `files/system/` and is copied to `/` by the `files` module. Tests are shell scripts: `tests/recipe.sh` checks that the recipe expands, `tests/image.sh` runs assertions inside a locally built image with `podman run`, and `tests/dotfiles-repo.sh` checks that applying the dotfiles repo puts nothing unexpected in `~`.

**Tech Stack:** BlueBuild (recipe v1, modules `dnf`, `files`, `systemd`, `script`, `fonts`, `default-flatpaks` v2, `signing`), Podman 6, bash, firewalld offline tools, OpenSSH `sshd -T`.

**Spec:** `docs/superpowers/specs/2026-10-24-bastion-image-design.md`

## Global Constraints

- Base image: `ghcr.io/ublue-os/bazzite`, `image-version: stable`. Image `name: bastion`.
- **Every package bastion depends on is declared explicitly, even if Bazzite already ships it.** `tests/image.sh` checks each declared package with `rpm -q`.
- **Deviation from the spec (BlueBuild requirement):** the spec says `modules/*.yml`, but BlueBuild resolves `from-file:` relative to `recipes/`, and the top-level `modules/` directory is reserved for custom module *code*. Module files therefore go in `recipes/modules/<name>.yml`, keeping the spec's names (`desktop`, `gaming`, `remote`, `dev-languages`, `ai-agents`, `cli-tools`, `containers`, `apps`, `chat`). Delete the top-level `modules/` directory.
- Leave `recipes/indeos-remote.yml` untouched. Remove `indeos.yml` from the workflow matrix and add `bastion.yml`.
- Owner user: `indegrowl`, UID 1000. Hostname: `bastion`.
- No Claude Code in the image. No Discord TUI. No Plasma, no SDDM. Dolphin, KIO and KWallet stay.
- Config goes in `/etc` or `/usr`. Never write to `/home`, `/var`, `/mnt` or `/opt` at build time. Use tmpfiles.d for anything that has to exist in `/var`.
- `/mnt` is a symlink to `/var/mnt` on atomic Fedora, so the data mount unit is `var-mnt-data.mount` with `Where=/var/mnt/data`.
- Data drive UUID: `5ade185d-b4a7-4dfb-80d8-691830837386`, btrfs, options `noatime,compress=zstd:1,nofail,x-systemd.device-timeout=10s`.
- Tailscale ranges: `100.64.0.0/10` and `fd7a:115c:a1e0::/48`.
- Dotfiles repo: `https://github.com/indegrowl/dotfiles.git`, cloned by BlueBuild's chezmoi module into the default `~/.local/share/chezmoi`.
- Work on branch `bastion-image`. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Tailscale down or not yet logged in:** password SSH must not open up on the LAN. Pinned in Task 3: `sshd -T` from a LAN address reports `passwordauthentication no`, and the LAN zone has no `ssh` service.
2. **Data drive missing or unplugged:** boot must not hang. Pinned in Task 8: the unit has `nofail` and a device timeout.
3. **Dotfiles repo holds only `LICENSE`/`README.md`:** first-login apply must not drop those into `~`. Pinned in Task 7: `tests/dotfiles-repo.sh` asserts `chezmoi managed` is empty.
4. **Hyprland crashes or exits:** the machine falls back to tuigreet, not a black screen or a login loop. Pinned in Task 2: greetd config has a `default_session` running tuigreet.
5. **Stray suspend trigger (a keyboard sleep key, an idle daemon):** the machine still stays awake. Pinned in Task 3: all four sleep targets are masked, so even an explicit `systemctl suspend` is refused.

---

### Task 1: Recipe skeleton, test harness, workflow

**Files:**
- Create: `recipes/bastion.yml`, `recipes/modules/dev-languages.yml`, `tests/lib.sh`, `tests/recipe.sh`, `tests/build.sh`, `tests/image.sh`
- Delete: `recipes/indeos.yml`, `modules/dev-languages.yml` (and the `modules/` directory)
- Modify: `.github/workflows/build.yml` (matrix)
- Add (uncommitted until now): `docs/superpowers/specs/2026-10-24-bastion-image-design.md`, this plan

**Interfaces:**
- Produces: `tests/lib.sh` with `assert_pkg <pkg>...`, `assert_no_pkg <pkg>...`, `assert_file <path>`, `assert_grep <regex> <path>`, `assert_enabled <unit> [system|user]`, `assert_masked <unit>`. Each prints `ok`/`FAIL` with what it checked, and sets a global failure flag. `run_in_image <cmd...>` runs a command in `$IMAGE` via `podman run --rm --entrypoint /bin/bash "$IMAGE" -c`.
- Produces: `tests/image.sh` sources `lib.sh`, takes `IMAGE` (default `localhost/bastion:latest`), runs one section function per task (`check_base`, `check_desktop`, `check_remote`, …), and exits 1 if anything failed. Later tasks add their section function and the call.
- Produces: `tests/build.sh` builds `recipes/bastion.yml` locally into `localhost/bastion:latest`.
- Produces: `recipes/bastion.yml` with `modules:` listing `- from-file: modules/<name>.yml` entries, plus `type: signing` last. Later tasks append their `from-file` line before `signing`.

- [ ] **Step 1: Branch and commit the spec and plan**

```bash
git switch -c bastion-image
git add docs/superpowers
git commit -m "docs: bastion image design and plan"
```

- [ ] **Step 2: Install the BlueBuild CLI**

Run `cargo install --locked blue-build` (the crate behind the `bluebuild` binary, version 0.9 or newer). Check: `bluebuild --version` prints a version. If the crate name has changed, use the install method in the BlueBuild CLI README.

- [ ] **Step 3: Write `tests/recipe.sh` (failing)**

It runs `bluebuild generate -d recipes/bastion.yml -o "$(mktemp)"` and fails if that fails. It also asserts that `recipes/indeos.yml` and `modules/` don't exist, and that `build.yml`'s matrix contains `bastion.yml` and `indeos-remote.yml` but not `indeos.yml`.

Run: `bash tests/recipe.sh` → FAIL (no `bastion.yml`).

- [ ] **Step 4: Write `tests/lib.sh`, `tests/build.sh`, and `tests/image.sh` with `check_base`**

`check_base` asserts:
- `/usr/lib/os-release` contains `bazzite`
- `assert_pkg rustup mise gcc clang mold python3-devel lua-devel`
- `assert_no_pkg golang luajit luarocks`

`tests/build.sh` runs `bluebuild build -B podman --tempdir "$HOME/.cache/bluebuild" recipes/bastion.yml`, then tags the result `localhost/bastion:latest`. The builder confirms which local tag the CLI produces and adjusts.

- [ ] **Step 5: Create the recipe and dev-languages module; fix the workflow**

`recipes/bastion.yml`:
- schema line `# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json`
- `name: bastion`, a short description, the Global Constraints base image and version
- modules: `from-file: modules/dev-languages.yml`, then `type: signing`

`recipes/modules/dev-languages.yml`: a module-list file (`module-list-v1.json` schema) with one `dnf` module.
- Install: rustup, mise (COPR `jdxcode/mise`), gcc, clang, mold, python3-devel, lua-devel
- Remove `golang`, `luajit` and `luarocks` only if Bazzite ships them. Otherwise just don't install them.

Delete `recipes/indeos.yml` and `modules/`. In `build.yml`, change the matrix to `bastion.yml` and `indeos-remote.yml`.

- [ ] **Step 6: Verify**

Run `bash tests/recipe.sh`, then `bash tests/build.sh && bash tests/image.sh`. Expected: all `ok`, exit 0. The first build pulls Bazzite (several GB), so allow time.

- [ ] **Step 7: Commit**

`git add -A recipes modules tests .github && git commit -m "feat: bastion recipe skeleton and test harness"`

---

### Task 2: Desktop — Hyprland, greetd autologin, Plasma removal

**Files:**
- Create: `recipes/modules/desktop.yml`, `files/system/etc/greetd/config.toml`, `files/system/usr/lib/tmpfiles.d/bastion-linger.conf`, `files/system/etc/environment.d/50-bastion-dolphin.conf` (or the builder's equivalent fix for Dolphin's "Open with" menu)
- Modify: `recipes/bastion.yml`, `tests/image.sh`

**Interfaces:**
- Consumes: `lib.sh` helpers; the `from-file` pattern from Task 1.
- Produces: a `files` module entry (`source: system`, `destination: /`) in `desktop.yml`. It's the **only** `files` module, and later tasks rely on it to copy their files under `files/system/`.

- [ ] **Step 1: Add `check_desktop` to `tests/image.sh` (failing)**

Assertions:
- `assert_pkg hyprland hyprlock hypridle hyprpaper xdg-desktop-portal-hyprland xdg-desktop-portal-gtk uwsm qt5-qtwayland qt6-qtwayland hyprpolkitagent waybar fuzzel mako kitty greetd tuigreet dolphin kwallet kio`. Use whatever the exact Fedora package names of KIO and KWallet are, e.g. `kf6-kio-core` and `kf6-kwallet`.
- `assert_no_pkg sddm plasma-workspace plasma-desktop kwin konsole kate gwenview plasma-discover`
- `assert_grep '^\[initial_session\]' /etc/greetd/config.toml`
- `assert_grep 'command *= *"uwsm start hyprland.desktop"' /etc/greetd/config.toml`
- `assert_grep 'user *= *"indegrowl"' /etc/greetd/config.toml`
- `assert_grep '^\[default_session\]' /etc/greetd/config.toml`, plus a tuigreet command line in that section (Review Focus 4)
- `assert_enabled greetd.service`; `sddm.service` is not present
- `assert_grep 'indegrowl' /usr/lib/tmpfiles.d/bastion-linger.conf`, which must hold the line `f /var/lib/systemd/linger/indegrowl`

Run `bash tests/image.sh` against the Task 1 image → `check_desktop` FAILs.

- [ ] **Step 2: Write `desktop.yml`**

It contains these modules:
1. `dnf`:
   - Add COPR `sdegler/hyprland`. The builder checks that it has builds for Bazzite's current Fedora release; if not, they use the most recently updated Hyprland COPR and note that in the commit.
   - Install the packages from Step 1.
   - Remove the Plasma, SDDM and KDE app packages with `auto-remove: false`, so Dolphin's KIO and KWallet dependencies stay.
2. `files` (`system` → `/`).
3. `systemd`: enable `greetd.service` (system).

greetd config:
- `[terminal] vt = 1`
- `[initial_session]` with `command = "uwsm start hyprland.desktop"` and `user = "indegrowl"`
- `[default_session]` with `command = "tuigreet --time --remember --cmd 'uwsm start hyprland.desktop'"` and `user = "greeter"`

- [ ] **Step 3: Add `from-file: modules/desktop.yml` to the recipe; rebuild and test**

Run: `bash tests/recipe.sh && bash tests/build.sh && bash tests/image.sh`. Expected: everything `ok`.

If removing Plasma pulls out something Bazzite needs, the build or `check_base` fails. The fix is to trim the remove list. Never add `allow-erasing` to force it through.

- [ ] **Step 4: Commit**

`git commit -m "feat: hyprland desktop with greetd autologin, drop plasma/sddm"`

---

### Task 3: Remote access, firewall, never-sleep, hostname, updates

**Files:**
- Create:
  - `recipes/modules/remote.yml`
  - `files/system/etc/ssh/sshd_config.d/50-bastion.conf`
  - `files/system/etc/firewalld/firewalld.conf`, or a drop-in that sets `DefaultZone=bastion-lan`
  - `files/system/etc/firewalld/zones/bastion-lan.xml`
  - `files/system/etc/firewalld/zones/trusted.xml`
  - `files/system/etc/hostname`
- Modify: `recipes/bastion.yml`, `tests/image.sh`

**Interfaces:**
- Consumes: the Task 2 `files` module, which copies everything under `files/system/`.
- Produces: the LAN zone named `bastion-lan`.

- [ ] **Step 1: Add `check_remote` (failing)**

These run inside the image. For the `sshd -T` checks, generate throwaway host keys first with `ssh-keygen -A`.

```bash
assert_pkg openssh-server tailscale firewalld avahi nss-mdns
assert_enabled sshd.service; assert_enabled tailscaled.service; assert_enabled avahi-daemon.service
# sshd: Tailscale gets passwords, LAN does not, root never
sshd -T -C user=indegrowl,host=x,addr=100.101.1.2 | grep -qx 'passwordauthentication yes'
sshd -T -C user=indegrowl,host=x,addr=fd7a:115c:a1e0::5 | grep -qx 'passwordauthentication yes'
sshd -T -C user=indegrowl,host=x,addr=192.168.1.50 | grep -qx 'passwordauthentication no'
sshd -T -C user=indegrowl,host=x,addr=100.101.1.2 | grep -qx 'permitrootlogin no'
# firewall
firewall-offline-cmd --get-default-zone            # == bastion-lan
firewall-offline-cmd --zone=trusted --list-interfaces   # contains tailscale0
firewall-offline-cmd --zone=bastion-lan --list-services # contains mdns, NOT ssh
firewall-offline-cmd --zone=bastion-lan --list-ports    # == the port list below
# never sleep
for t in sleep suspend hibernate hybrid-sleep; do assert_masked $t.target; done
# identity / updates
assert_grep '^bastion$' /etc/hostname
assert_grep '^AutomaticUpdatePolicy=stage' /etc/rpm-ostreed.conf   # or Bazzite's equivalent; no reboot
```

The builder also checks how Bazzite's own update service (`uupd` or `ublue-update`) behaves. If it can reboot, the builder turns that off through its config and adds an assertion for it.

Run → FAIL.

- [ ] **Step 2: Write the config**

- **`50-bastion.conf`:**
  - Global: `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`.
  - Then `Match Address 100.64.0.0/10,fd7a:115c:a1e0::/48` with `PasswordAuthentication yes`.
  - The Match block goes last in the file, since sshd applies the first value it finds, and Fedora's own drop-ins load first.
- **`bastion-lan.xml`:**
  - Services: `mdns`.
  - Ports: Steam Remote Play `27031-27036/udp`, `27036/tcp`, `27037/tcp`; Sunshine `47984/tcp`, `47989/tcp`, `48010/tcp`, `47998-48000/udp`.
  - Sunshine's web UI (`47990/tcp`) is **not** opened on the LAN; it's reached over Tailscale.
- **`trusted.xml`:** `<interface name="tailscale0"/>`.
- **`remote.yml`:**
  - `dnf`: install the Step 1 packages. If `tailscale` isn't available, add repo file `https://pkgs.tailscale.com/stable/fedora/tailscale.repo`.
  - `systemd`: enable `sshd`, `tailscaled`, `avahi-daemon`, `firewalld`; mask the four sleep targets.

- [ ] **Step 3: Add `from-file` to the recipe, rebuild, test, commit**

Run: `bash tests/recipe.sh && bash tests/build.sh && bash tests/image.sh` → all `ok`.

`git commit -m "feat: tailscale-only password ssh, firewall zones, never sleep"`

---

### Task 4: Gaming, containers, CLI tools

**Files:**
- Create: `recipes/modules/gaming.yml`, `recipes/modules/containers.yml`, `recipes/modules/cli-tools.yml`
- Modify: `recipes/bastion.yml`, `tests/image.sh`

**Interfaces:** consumes the `lib.sh` helpers only.

- [ ] **Step 1: Add `check_gaming_and_tools` (failing)**

```bash
assert_pkg steam gamescope sunshine mesa-vulkan-drivers mesa-dri-drivers
assert_pkg podman distrobox podman-compose
assert_pkg kitty chezmoi neovim tmux zellij git lazygit starship gh btop glow pass gnupg2 \
           zoxide fzf ripgrep tree yazi wl-clipboard cliphist
```

Run → FAIL on the packages that aren't there yet.

- [ ] **Step 2: Write the three module files**

Each one is a single `dnf` module that installs its list.

COPRs: `atim/lazygit`, `atim/starship`, `lihaohong/yazi`. For `cliphist` and `zellij`, use the Fedora package if one exists, otherwise a maintained COPR. `sunshine` comes from Bazzite's repos; if it's missing, add COPR `lizardbyte/stable`.

`kitty` lives in `cli-tools.yml` as the spec says, so take it out of Task 2's `desktop.yml` and keep the `check_desktop` assertion.

- [ ] **Step 3: Add the three `from-file` lines, rebuild, test, commit**

`git commit -m "feat: gaming, container and cli tool modules"`

---

### Task 5: AI agents

**Files:**
- Create: `recipes/modules/ai-agents.yml`, `files/scripts/install-ai-agents.sh`
- Modify: `recipes/bastion.yml`, `tests/image.sh`

**Interfaces:** consumes the `lib.sh` helpers.

- [ ] **Step 1: Add `check_ai_agents` (failing)**

```bash
assert_pkg nodejs uv
run_in_image 'hermes --help >/dev/null'        # Nous Research hermes-agent CLI entry point
run_in_image 'pi --help >/dev/null'            # @mariozechner/pi-coding-agent
run_in_image '! command -v claude'             # Claude Code must NOT be in the image
run_in_image 'test -z "$(find /usr -name "claude*" -path "*bin*")"'
```

The builder confirms the exact executable names from each package's metadata and fixes the assertions if they differ.

Run → FAIL.

- [ ] **Step 2: Write the module and the script**

`ai-agents.yml`:
- `dnf` installs `nodejs` and `uv`. `uv` stays in the image as the tool installer, alongside mise.
- A `script` module runs `install-ai-agents.sh`.

The script starts with `#!/usr/bin/env bash` and `set -euo pipefail`, then:
- `UV_TOOL_DIR=/usr/lib/uv-tools UV_TOOL_BIN_DIR=/usr/bin uv tool install hermes-agent`
- `npm install -g --prefix /usr @mariozechner/pi-coding-agent`
- clears the npm and uv caches

- [ ] **Step 3: Add `from-file`, rebuild, test, commit**

`git commit -m "feat: hermes and pi agents module"`

---

### Task 6: Apps, chat, fonts, build123d libraries

**Files:**
- Create: `recipes/modules/apps.yml`, `recipes/modules/chat.yml`
- Modify: `recipes/bastion.yml`, `tests/image.sh`

**Interfaces:** consumes the `lib.sh` helpers and the Task 5 `uv tool` install pattern (same `UV_TOOL_DIR` and `UV_TOOL_BIN_DIR`).

- [ ] **Step 1: Add `check_apps` (failing)**

```bash
assert_pkg qutebrowser dolphin mesa-libGL libglvnd-glx fontconfig libX11 libXrender libXext
assert_pkg nchat
run_in_image 'zulip-term --version'
run_in_image 'fc-list | grep -qi "CaskaydiaCove"'
# flatpak list is resolved at boot; assert the declared IDs in the generated config
run_in_image 'grep -rq "com.bambulab.BambuStudio" /usr/share/bluebuild/default-flatpaks'
```

Also grep that config for `org.telegram.desktop`, `com.discordapp.Discord`, `org.zulip.Zulip`, `org.chromium.Chromium` and `com.obsproject.Studio`. The builder confirms where default-flatpaks v2 writes its config in the image and adjusts the path.

There's also a slow build123d check, run only when `SLOW=1` is set. It needs network.

```bash
run_in_image 'cd $(mktemp -d) && uv venv -q && uv pip install -q build123d && .venv/bin/python -c "from build123d import Box; assert Box(1,1,1).volume > 0.99"'
```

Run → FAIL.

- [ ] **Step 2: Write the modules**

`apps.yml`:
- `dnf` installs `qutebrowser`, `dolphin` and the build123d system libraries above.
- `fonts`, with `nerd-fonts: [CascadiaCode]`.
- `default-flatpaks` with `scope: system` and the seven IDs: the five above plus `com.bambulab.BambuStudio` and the OBS vkcapture plugin. Flathub IDs are checked at build time, so an ID typo fails the build.

`chat.yml`:
- `nchat` from Fedora or a COPR. The builder's call; if neither exists, use the upstream release build and note it.
- A `script` snippet that runs `uv tool install zulip-term` with the Task 5 environment variables.

- [ ] **Step 3: Add `from-file` lines, rebuild, test (including `SLOW=1` once), commit**

`git commit -m "feat: apps, chat clients, fonts, build123d libs"`

---

### Task 7: Dotfiles bootstrap (BlueBuild chezmoi module)

**Files:**
- Modify: `recipes/modules/cli-tools.yml` (add the `chezmoi` module), `tests/image.sh`
- Create: `tests/dotfiles-repo.sh`
- Already done in the dotfiles repo: `.chezmoiignore` (commit `091965d`)

**Interfaces:** consumes the `lib.sh` helpers.

- [ ] **Step 1: Add `check_dotfiles` to `image.sh` and write `tests/dotfiles-repo.sh` (both failing)**

`check_dotfiles` asserts:
- `assert_file /usr/lib/systemd/user/chezmoi-init.service`, with `ExecStart` containing `https://github.com/indegrowl/dotfiles.git`
- `assert_enabled chezmoi-init.service user`
- `chezmoi-update.timer` is **not** enabled, because the spec says no automatic updates
- `command -v chezmoi` succeeds

`tests/dotfiles-repo.sh` runs on the host:
1. Clone `https://github.com/indegrowl/dotfiles.git` into a temp directory. Use `DOTFILES_REPO` to override the URL, defaulting to `../dotfiles`.
2. Run `chezmoi --source "$tmp" --destination "$tmphome" managed`.
3. Assert the output is empty, so nothing (no `LICENSE`, no `README.md`) would land in `~`.
4. Run `chezmoi apply` against `$tmphome` and assert it creates no files.

Run both → FAIL.

- [ ] **Step 2: Add the module to `cli-tools.yml`**

```yaml
- type: chezmoi
  repository: https://github.com/indegrowl/dotfiles.git
  all-users: true
  disable-update: true
  file-conflict-policy: skip
```

The module downloads its own binary by default, which would clash with the dnf `chezmoi` package. If the module accepts `install: false`, set it and keep the dnf package. Otherwise drop `chezmoi` from the dnf list and the `assert_pkg chezmoi` check, and say so in the commit.

- [x] **Step 3: Add `.chezmoiignore` to `../dotfiles`** — done before execution (dotfiles commit `091965d`, pushed with owner approval; lists `LICENSE`, `README.md`).

- [ ] **Step 4: Verify and commit**

Run: `bash tests/dotfiles-repo.sh && bash tests/build.sh && bash tests/image.sh` → all `ok`.

`git commit -m "feat: chezmoi module bootstraps dotfiles on first login"`

---

### Task 8: Data drive mount, README

**Files:**
- Create: `files/system/usr/lib/systemd/system/var-mnt-data.mount`
- Modify: `recipes/modules/remote.yml` (enable the mount), `README.md`, `tests/image.sh`

**Interfaces:** consumes the Task 2 `files` module and the Task 3 `systemd` module.

- [ ] **Step 1: Add `check_storage` (failing)**

```bash
assert_grep '^What=/dev/disk/by-uuid/5ade185d-b4a7-4dfb-80d8-691830837386$' /usr/lib/systemd/system/var-mnt-data.mount
assert_grep '^Where=/var/mnt/data$' ...
assert_grep '^Type=btrfs$' ...
assert_grep '^Options=noatime,compress=zstd:1,nofail,x-systemd.device-timeout=10s$' ...   # Review Focus 2
assert_enabled var-mnt-data.mount
run_in_image 'systemd-analyze verify /usr/lib/systemd/system/var-mnt-data.mount'
```

Run → FAIL.

- [ ] **Step 2: Write the mount unit and enable it**

`[Install] WantedBy=multi-user.target`. Enable it in `remote.yml`'s `systemd` module.

- [ ] **Step 3: Rewrite `README.md`**

The README covers:
- what bastion is (one paragraph)
- the install steps from spec §7: Bazzite ISO, then the unsigned rebase to `ghcr.io/indegrowl/bastion:latest` and a reboot, then the signed rebase and a reboot
- the first-boot checklist, in this order:
  1. `tailscale up`
  2. add the laptop's SSH key
  3. install Claude Code per user
  4. switch the dotfiles remote to SSH
  5. streaming setup (spec §2)
- Remove the template text.

- [ ] **Step 4: Full verification**

Run `bash tests/recipe.sh && bash tests/dotfiles-repo.sh && bash tests/build.sh && SLOW=1 bash tests/image.sh`. Expected: every check `ok`, exit 0.

- [ ] **Step 5: Commit and push the branch**

```bash
git commit -m "feat: declare data drive mount, bastion README"
git push -u origin bastion-image
```

CI (`build.yml`) builds `bastion.yml` on the push. Check the run passes with `gh run watch`. Don't merge to `main` until the owner says so.
