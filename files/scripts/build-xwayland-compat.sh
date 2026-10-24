#!/usr/bin/env bash
# Build a metadata-only RPM so COPR Hyprland's arch-qualified
# "xorg-x11-server-Xwayland(x86-64)" requirement is met by Bazzite's
# terra-xorg-x11-server-Xwayland (which only provides the unqualified name).
set -euo pipefail
dnf -y install rpm-build
mkdir -p /tmp/rpmbuild/SPECS /out
cat > /tmp/rpmbuild/SPECS/bastion-xwayland-compat.spec <<'SPEC'
Name:           bastion-xwayland-compat
Version:        1
Release:        1
Summary:        Arch-qualified Xwayland provide for Bazzite's terra Xwayland
License:        MIT
BuildArch:      x86_64
Provides:       xorg-x11-server-Xwayland(x86-64)
Requires:       terra-xorg-x11-server-Xwayland

%description
Lets packages that require xorg-x11-server-Xwayland(x86-64) install on
Bazzite, whose Xwayland comes from Terra.

%files
SPEC
rpmbuild --define "_topdir /tmp/rpmbuild" -bb /tmp/rpmbuild/SPECS/bastion-xwayland-compat.spec
cp /tmp/rpmbuild/RPMS/x86_64/*.rpm /out/
