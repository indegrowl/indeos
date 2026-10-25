#!/usr/bin/env bash
# Runtime checks inside a built bastion image. Usage: IMAGE=<ref> tests/image.sh
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh

podman image exists "$IMAGE" || { echo "image $IMAGE not found; run tests/build.sh"; exit 1; }

check_base() {
  assert_grep 'bazzite' /usr/lib/os-release
  assert_pkg rustup mise gcc clang mold python3-devel lua-devel
  assert_no_pkg golang luarocks  # luajit stays: terra-gamescope links libluajit
}

check_desktop() {
  local g=/etc/greetd/config.toml
  assert_pkg hyprland hyprlock hypridle hyprpaper xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
             uwsm qt5-qtwayland qt6-qtwayland hyprpolkitagent waybar fuzzel mako kitty greetd tuigreet \
             dolphin kf6-kio-core kf6-kwallet redhat-menus
  # Bazzite's gaming Xwayland must survive the Hyprland install
  assert_pkg terra-xorg-x11-server-Xwayland bastion-xwayland-compat
  assert_no_pkg sddm plasma-login-manager plasma-workspace plasma-desktop kwin konsole kate gwenview plasma-discover
  # initial_session: silent autologin into Hyprland via uwsm
  check "greetd initial_session autologs indegrowl into uwsm/hyprland" \
    "awk '/^\[initial_session\]/{s=1;next} /^\[/{s=0} s' $g | grep -qE 'command *= *\"uwsm start hyprland.desktop\"' &&
     awk '/^\[initial_session\]/{s=1;next} /^\[/{s=0} s' $g | grep -qE 'user *= *\"indegrowl\"'"
  # default_session: tuigreet fallback when the session exits or crashes
  check "greetd default_session runs tuigreet as a user sysusers creates" \
    "awk '/^\[default_session\]/{s=1;next} /^\[/{s=0} s' $g | grep -qE 'command *= *\"tuigreet .*uwsm start hyprland.desktop' &&
     u=\$(awk '/^\[default_session\]/{s=1;next} /^\[/{s=0} s' $g | sed -nE 's/^user *= *\"(.*)\"/\\1/p') &&
     grep -qE \"^u +\$u \" /usr/lib/sysusers.d/*.conf"
  assert_enabled greetd.service
  check "plasmalogin shadow workaround unit not enabled" \
    "! systemctl is-enabled fedora-kinoite-plasmalogin-workaround.service 2>/dev/null | grep -qx enabled"
  check "display-manager.service points at greetd" \
    "[ \"\$(basename \"\$(readlink -f /etc/systemd/system/display-manager.service)\")\" = greetd.service ]"
  assert_grep '^f /var/lib/systemd/linger/indegrowl' /usr/lib/tmpfiles.d/bastion-linger.conf
  # greetd's home and tuigreet's --remember cache live in /var, which images don't populate
  assert_grep '^d /var/lib/greetd 0750 greetd greetd' /usr/lib/tmpfiles.d/bastion-greetd.conf
  assert_grep '^d /var/cache/tuigreet 0755 greetd greetd' /usr/lib/tmpfiles.d/bastion-greetd.conf
  # GUI privilege prompts work before any dotfiles exist
  assert_enabled hyprpolkitagent.service user
  # Dolphin's "Open with" needs an applications.menu once Plasma's menu file is gone
  assert_file /etc/xdg/menus/applications.menu
}

check_remote() {
  local sshT='ssh-keygen -A >/dev/null 2>&1; sshd -T -C user=indegrowl,host=x'
  assert_pkg openssh-server tailscale firewalld avahi nss-mdns
  assert_enabled sshd.service
  assert_enabled tailscaled.service
  assert_enabled avahi-daemon.service
  assert_enabled firewalld.service
  # Password SSH only from Tailscale; root never (Review Focus 1)
  check "sshd: password auth from Tailscale IPv4" "$sshT,addr=100.101.1.2 | grep -qx 'passwordauthentication yes'"
  check "sshd: password auth from Tailscale IPv6" "$sshT,addr=fd7a:115c:a1e0::5 | grep -qx 'passwordauthentication yes'"
  check "sshd: no password auth from LAN"         "$sshT,addr=192.168.1.50 | grep -qx 'passwordauthentication no'"
  check "sshd: no keyboard-interactive from LAN"  "$sshT,addr=192.168.1.50 | grep -qx 'kbdinteractiveauthentication no'"
  check "sshd: no root login from Tailscale"      "$sshT,addr=100.101.1.2 | grep -qx 'permitrootlogin no'"
  check "sshd: no root login from LAN"            "$sshT,addr=192.168.1.50 | grep -qx 'permitrootlogin no'"
  # Firewall: LAN zone has streaming + mDNS only, Tailscale fully trusted
  assert_enabled bastion-firewall-zone.service
  check "boot unit resets a drifted default zone to bastion-lan before firewalld" \
    "firewall-offline-cmd --set-default-zone=FedoraWorkstation >/dev/null &&
     /usr/libexec/bastion-firewall-zone && [ \"\$(firewall-offline-cmd --get-default-zone)\" = bastion-lan ] &&
     grep -qx 'Before=firewalld.service' /usr/lib/systemd/system/bastion-firewall-zone.service"
  check "firewall default zone is bastion-lan" "[ \"\$(firewall-offline-cmd --get-default-zone)\" = bastion-lan ]"
  check "tailscale0 in trusted zone" "firewall-offline-cmd --zone=trusted --list-interfaces | grep -qw tailscale0"
  check "LAN zone services are exactly mdns" "[ \"\$(firewall-offline-cmd --zone=bastion-lan --list-services)\" = mdns ]"
  check "LAN zone ports are exactly the streaming ports" \
    "[ \"\$(firewall-offline-cmd --zone=bastion-lan --list-ports | tr ' ' '\n' | sort | tr '\n' ' ')\" = \
       '27031-27036/udp 27036/tcp 27037/tcp 47984/tcp 47989/tcp 47998-48000/udp 48010/tcp ' ]"
  # Never sleep (Review Focus 5)
  local t; for t in sleep suspend hibernate hybrid-sleep; do assert_masked "$t.target"; done
  # Identity and updates: stage automatically, never reboot
  # /etc/hostname can't ship in an image layer (buildah strips it); a boot unit sets it
  local hn=/usr/lib/systemd/system/bastion-hostname.service
  assert_grep '^ExecStart=/usr/bin/hostnamectl set-hostname bastion$' $hn
  assert_grep '^ConditionHost=!bastion$' $hn
  assert_enabled bastion-hostname.service
  assert_enabled uupd.timer
  check "uupd stages without rebooting (no --apply)" "grep -q '^ExecStart=/usr/bin/uupd' /usr/lib/systemd/system/uupd.service && ! grep -q -- '--apply' /usr/lib/systemd/system/uupd.service"
  check "auto-rebooting bootc timer not enabled" "! systemctl is-enabled bootc-fetch-apply-updates.timer 2>/dev/null | grep -qx enabled"
}

check_gaming_and_tools() {
  assert_pkg steam gamescope terra-gamescope Sunshine mesa-vulkan-drivers mesa-dri-drivers
  assert_pkg podman distrobox podman-compose
  assert_pkg kitty neovim tmux zellij git lazygit starship gh btop glow pass gnupg2 \
             zoxide fzf ripgrep tree yazi wl-clipboard cliphist
  # /home -> /var/home: shells starting in the resolved home switch to $HOME (prompt shows ~)
  assert_file /etc/profile.d/bastion-home.sh
  check "interactive bash in the resolved home moves to \$HOME" \
    "mkdir -p /var/home/t && cd /var/home/t && [ \"\$(HOME=/home/t bash -i -c 'echo \$PWD' 2>/dev/null | tail -n1)\" = /home/t ]"
  check "interactive bash elsewhere stays put" \
    "cd /tmp && [ \"\$(HOME=/home/t bash -i -c 'echo \$PWD' 2>/dev/null | tail -n1)\" = /tmp ]"
}

check_ai_agents() {
  assert_pkg nodejs uv python3.13
  check "hermes (Nous Research hermes-agent) runs" "hermes --help"
  check "hermes-agent is the Nous Research package" \
    "grep -q '^Author: Nous Research' /usr/lib/uv-tools/hermes-agent/lib/python3.13/site-packages/hermes_agent-*.dist-info/METADATA"
  check "pi (@earendil-works/pi-coding-agent) runs" "pi --help"
  check "Claude Code is not in the image" "! command -v claude && [ -z \"\$(find /usr -path '*bin*' -name 'claude*' 2>/dev/null)\" ]"
  check "no npm/uv caches left in image" "[ ! -d /root/.npm ] && [ ! -d /root/.cache/uv ]"
}

check_apps() {
  assert_pkg qutebrowser dolphin obs-studio-plugin-vkcapture-hook-libs
  # build123d's OCP/OpenCascade wheels load these at import time
  assert_pkg mesa-libGL libglvnd-glx fontconfig libX11 libXrender libXext
  check "nchat installed" "nchat --version"
  check "zulip-term installed" "zulip-term --version"
  check "Cascadia Code Nerd Font installed" "fc-list | grep -qi 'CaskaydiaCove'"
  local id
  for id in org.telegram.desktop com.discordapp.Discord org.zulip.Zulip org.chromium.Chromium \
            com.obsproject.Studio com.obsproject.Studio.Plugin.OBSVkCapture com.bambulab.BambuStudio; do
    check "flatpak declared: $id" "grep -rqF '$id' /usr/share/bluebuild/default-flatpaks"
  done
  if [[ "${SLOW:-0}" == 1 ]]; then
    if podman run --rm --entrypoint /bin/bash "$IMAGE" -c \
      'export HOME=/tmp; cd "$(mktemp -d)" && uv venv -q --python 3.13 && uv pip install -q build123d &&
       .venv/bin/python -c "from build123d import Box; assert Box(1,1,1).volume > 0.99"' >/dev/null 2>&1
    then ok "build123d imports and builds a solid"; else fail "build123d imports and builds a solid"; fi
  fi
}

check_dotfiles() {
  local u=/usr/lib/systemd/user/chezmoi-init.service
  assert_file $u
  check "chezmoi-init clones indegrowl/dotfiles" "grep -rqF 'https://github.com/indegrowl/dotfiles.git' $u /usr/lib/systemd/user/chezmoi-init.service.d 2>/dev/null"
  assert_enabled chezmoi-init.service user
  # Lingering starts it at boot, maybe before the network: it must retry
  check "chezmoi-init retries on failure" \
    "systemctl --global cat chezmoi-init.service 2>/dev/null | grep -qx 'Restart=on-failure' || grep -rqx 'Restart=on-failure' /usr/lib/systemd/user/chezmoi-init.service.d/"
  check "chezmoi-init skips system users (greetd's greeter session)" \
    "grep -rqx 'ConditionUser=!@system' /usr/lib/systemd/user/chezmoi-init.service.d/"
  check "no automatic chezmoi update" "! systemctl --global is-enabled chezmoi-update.timer 2>/dev/null | grep -qx enabled"
  check "chezmoi runs (provided by the chezmoi module)" "chezmoi --version"
  check "exactly one chezmoi binary on PATH" "[ \"\$(which -a chezmoi | xargs -n1 readlink -f | sort -u | wc -l)\" = 1 ]"
}

check_storage() {
  local m=/usr/lib/systemd/system/var-mnt-data.mount
  assert_grep '^What=/dev/disk/by-uuid/5ade185d-b4a7-4dfb-80d8-691830837386$' $m
  assert_grep '^Where=/var/mnt/data$' $m
  assert_grep '^Type=btrfs$' $m
  # Missing drive must never block boot (Review Focus 2)
  assert_grep '^Options=noatime,compress=zstd:1,nofail$' $m
  # A missing drive gives up after 10s (x-systemd.device-timeout only works in fstab)
  assert_grep '^JobRunningTimeoutSec=10s$' '/usr/lib/systemd/system/dev-disk-by\x2duuid-5ade185d\x2db4a7\x2d4dfb\x2d80d8\x2d691830837386.device.d/10-bastion-timeout.conf'
  # Bazzite's automounter would race us for the labelled drive
  check "ublue-os-media-automount disabled" "! systemctl is-enabled ublue-os-media-automount.service 2>/dev/null | grep -qx enabled"
  assert_enabled var-mnt-data.mount
  check "/mnt resolves to /var/mnt" "[ \"\$(readlink -f /mnt)\" = /var/mnt ]"
}

check_base
check_desktop
check_remote
check_gaming_and_tools
check_ai_agents
check_apps
check_dotfiles
check_storage
finish
