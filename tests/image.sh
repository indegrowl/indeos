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
  # Dolphin's "Open with" needs an applications.menu once Plasma's menu file is gone
  assert_file /etc/xdg/menus/applications.menu
}

check_base
check_desktop
finish
