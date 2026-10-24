# bastion &nbsp; [![bluebuild build badge](https://github.com/indegrowl/indeos/actions/workflows/build.yml/badge.svg)](https://github.com/indegrowl/indeos/actions/workflows/build.yml)

`bastion` is the image for my always-on desktop: [Bazzite](https://bazzite.gg) (AMD) with Hyprland instead of KDE. It games (mostly streamed to my phone with Steam Remote Play or Sunshine/Moonlight), works as a dev box I reach over SSH via Tailscale, and will host the arr stack in Podman. It boots straight into Hyprland through greetd, never sleeps, and only lets passwords into SSH from Tailscale.

Design: [`docs/superpowers/specs/2026-10-24-bastion-image-design.md`](docs/superpowers/specs/2026-10-24-bastion-image-design.md). The recipe is [`recipes/bastion.yml`](recipes/bastion.yml), with one module file per area in [`recipes/modules/`](recipes/modules/).

(`recipes/indeos-remote.yml` is a separate, older image and isn't covered here.)

## Installation

1. Boot the stock Bazzite installer ISO (KDE, AMD) and install to the system NVMe (`nvme1n1`). That wipes the old system. Leave the 2TB data drive (`nvme0n1`) alone.
2. Create the user `indegrowl` (UID 1000, so files on the data drive keep their owner).
3. Rebase to the unsigned image first, so the signing keys and policies get installed:
   ```
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/indegrowl/bastion:latest
   systemctl reboot
   ```
4. Then rebase to the signed image:
   ```
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/indegrowl/bastion:latest
   systemctl reboot
   ```

`latest` always points at the newest build. Bazzite's update service downloads and stages new builds automatically, and **never reboots on its own**. Updates apply on your next reboot.

## First boot

Do these in order, at the local keyboard:

1. `sudo tailscale up` (and log in). SSH only works over Tailscale, so remote access starts here.
2. Add the laptop's public key to `~/.ssh/authorized_keys`.
3. Install Claude Code for your user. It isn't in the image, which is public.
4. Dotfiles: chezmoi already cloned `github.com/indegrowl/dotfiles` into `~/.local/share/chezmoi` (`chezmoi cd` takes you there). To be able to push, switch the remote to SSH: `chezmoi git -- remote set-url origin git@github.com:indegrowl/dotfiles.git`. Run `chezmoi update` yourself whenever you want; nothing updates automatically.
5. Streaming: set up the headless gamescope session for Steam Remote Play and Sunshine, and pair Moonlight. Sunshine's web UI is reachable over Tailscale only. The resulting user services belong in the dotfiles.

The data drive mounts at `/mnt/data`. If it's missing, boot carries on without it.

## Development

```bash
cargo install --locked blue-build   # bluebuild CLI
bash tests/recipe.sh                # recipe expands, repo layout is right
bash tests/dotfiles-repo.sh         # dotfiles repo applies cleanly
bash tests/build.sh                 # build localhost/bastion:latest with podman
SLOW=1 bash tests/image.sh          # checks inside the built image (SLOW=1 adds the build123d check)
```

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/indegrowl/bastion
```
