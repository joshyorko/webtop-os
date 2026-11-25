# Omarchy 4.5 (Quattro RS) Cloud-Native Webtop

A cloud-native, unprivileged OCI container image running **[Omarchy 4.5 ("Quattro RS")](https://github.com/omacom/omarchy)** natively on **LinuxServer's Arch + Selkies Wayland** base layer (`ghcr.io/linuxserver/baseimage-selkies:arch`), defined with a standard `Containerfile` and `compose.yaml`.

## Architecture & Prior Art

- **Upstream Omarchy 4.5.0 (Quattro RS)**: Installed directly from Omarchy's official signed repository (`https://pkgs.omarchy.org/stable/$arch`) paired with Omarchy's synchronized Arch mirror (`https://stable-mirror.omarchy.org`), including **Hyprland**, **Quickshell (`omarchy-shell`)**, **OWE**, **Nautilus**, **Foot**, **Neovim (`omarchy-nvim`)**, **Omarchy Chromium**, **Aether**, **Hype**, **Monologue**, **Signed**, and **Disktree**.
- **Base OS Layer (`ghcr.io/linuxserver/baseimage-selkies:arch`)**: Native Arch Linux with Selkies WebRTC/WebCodecs streaming, Pixelflux headless Smithay Wayland server (`PIXELFLUX_WAYLAND=true`), Pcmflux audio, and `s6-overlay`.
- **Clean Separate Profile Template (`/defaults/omarchy-profile`)**: Follows Kasm-style image separation by baking a pinned, credential-free Omarchy default profile outside `/config`. On boot, `omarchy-init-home` runs strictly as desktop user `abc`, fills only missing defaults into `/config`, safely retries if an earlier boot was interrupted, and never overwrites persisted user themes or configs.
- **Unprivileged Cloud-Native Runtime**: Runs unprivileged (no `privileged: true`, no KVM/QEMU VM overhead unlike `overthinkinglabs/domarchy`, no vendor-specific NVIDIA compose forks) using standard Linux `/dev/dri` DRM render nodes (host GPU, `virtio-gpu`, or kernel `modprobe vkms` on GPU-less Linux VMs), which Aquamarine (`CGBMAllocator` + `zwp_linux_dmabuf_v1`) requires for nested Hyprland.
- **Pre-installed Developer & Automation Tools**: Includes `action-server` (latest release from [`joshyorko/actions`](https://github.com/joshyorko/actions)), `rcc` (latest release from [`joshyorko/rcc`](https://github.com/joshyorko/rcc)), `mise`, `lazygit`, `lazydocker`, `github-cli`, `aws-cli-v2`, `ansible`, `minio-client`, `neovim`, `tmux`, `ripgrep`, `fd`, `fzf`, and `zoxide`.
- **Container Shims (`/usr/local/bin`)**: Lightweight `systemd-cat`, `uwsm-app`, and `systemd-run` shims allow Omarchy's upstream scripts to run seamlessly under `s6-overlay` without PID 1 systemd, alongside `wrapped-chromium` for container-safe Wayland Ozone launching.

## Quick Start

1. Optional: copy `.env.example` to `.env` if you want custom ports, timezone, or authentication credentials (no credentials are baked into the image or `compose.yaml`):
   ```bash
   cp .env.example .env
   ```
2. Build and start with Compose (`docker compose` or `podman compose`):
   ```bash
   docker compose up -d --build
   ```
   Or build the OCI image directly from `Containerfile`:
   ```bash
   docker build -f Containerfile -t omarchy-quattro:latest .
   ```
3. Open the web desktop:
   - HTTP: `http://localhost:3000`
   - HTTPS: `https://localhost:3001`

## Essential Omarchy Keybindings

| Shortcut | Action |
| :--- | :--- |
| `Super + Space` | Omarchy Launcher / Search |
| `Super + Alt + Space` | Omarchy Menu |
| `Super + Return` | Open Terminal (`foot` via `xdg-terminal-exec`) |
| `Super + Shift + B` | Open Browser (`chromium`) |
| `Super + L` | Cycle workspace layout (tiling / scrolling / floating) |
| `Super + W` | Close active window |
| `Super + 1..9` | Switch workspace |

> Tip: If your local host also uses `Super` keybindings, open the Selkies sidebar in the browser and enable fullscreen/keyboard grab so `Super` shortcuts pass directly into the container.

## Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `CUSTOM_USER` | _(unset)_ | Optional Selkies HTTP basic auth username (supply via `.env` or secret) |
| `PASSWORD` | _(unset)_ | Optional Selkies HTTP basic auth password (supply via `.env` or secret) |
| `SUDO_PASSWORD` | _(unset)_ | Optional password for `sudo` inside the container |
| `PORT_HTTP` / `PORT_HTTPS` | `3000` / `3001` | Host ports published by `compose.yaml` |
| `OMARCHY_MODE` | `1920x1080@60` | Default Hyprland output resolution and refresh rate (applied on initial config seed) |
| `OMARCHY_SCALE` | `1` | Default Hyprland monitor scale (applied on initial config seed) |
| `OMARCHY_GDK_SCALE` | `1` | Default XWayland/GDK integer scale (applied on initial config seed) |
| `UPDATE_ACTIONS_TOOLS` | `false` | Set to `true` to refresh `action-server` (`joshyorko/actions`) and `rcc` (`joshyorko/rcc`) on container boot |

## Logs & Troubleshooting

- Container-shim logs (profile init, Quickshell, Hyprland, PipeWire) are stored inside your persistent `/config` home:
  - `webtop-config/.local/state/omarchy/logs/profile-init.log`
  - `webtop-config/.local/state/omarchy/logs/hyprland.log`
  - `webtop-config/.local/state/omarchy/logs/omarchy-shell.log`
