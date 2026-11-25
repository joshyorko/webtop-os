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

## Tracked desktop customizations

- Save wallpapers under `extensions/backgrounds/<theme-slug>/`, such as
  `extensions/backgrounds/tokyo-night/`. Shared extension files are baked into
  the image and seeded into `/config/webtop-extensions` when missing.
- To edit the tracked files live on the Docker host, add the extensions override.
  The desktop UID/GID needs write access to that directory.
  ```bash
  docker compose -f compose.yaml -f compose.extensions.yaml up -d
  git status --short -- extensions/
  ```
  Set `WEBTOP_EXTENSIONS_HOST_DIR` to an existing dedicated directory to use a
  different source. The same `/config` stores private files and desktop state
  across container replacements. Keep the extension mount enabled when the
  selected wallpaper lives there.
- The wallpaper picker and cycler read the linked media from Omarchy's user
  backgrounds directory. Reopen the picker after updating a file in place.
  For a new filename, run `webtop-link-extensions` in the Webtop terminal,
  then `omarchy-theme-bg-switcher`. To extend the native menu, add
  `extensions/omarchy-menu.jsonc` and run `webtop-link-extensions`. An existing
  personal menu takes precedence. Restart the desktop if Quickshell still
  shows the previous menu.
- Add extra repository packages to `packages-extra.txt`, one name per line.
  The image installs them with the desktop packages in the full Arch upgrade.
  See `/usr/share/webtop/installed-packages.txt` for the resolved versions.

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

## Webtop Identity and Host Authentication

LinuxServer runs its services as `abc` and maps that account to `PUID` and `PGID`.
`WEBTOP_USER` defaults to `kdlocpanda` and provides a second name for the same
UID, primary group, supplemental groups, shell, and `/config` home. Lookups by
UID continue to return `abc`. A conflicting existing account stops initialization.
Use `WEBTOP_USER=abc` to run with a single name. Recreate the container after
changing the identity or UID/GID. The repository's separate ROR Dev Container
uses the image's existing `vscode` account.

`WEBTOP_GIT_NAME` and `WEBTOP_GIT_EMAIL` are Git system defaults. The defaults
are `joshyorko` and `joshyorko@users.noreply.github.com`. Existing global and
repository Git settings take precedence. Passing `SUDO_PASSWORD` to the service
requires that password for both Webtop account names through Arch's sudo/PAM
stack. With the variable unset, both password entries are locked and the
LinuxServer passwordless sudo policy applies when sudo is enabled.

Use `compose.host-auth.yaml` as the final Compose override on the desktop host.
It publishes Webtop on IPv4 loopback and mounts a dedicated auth directory
read-only. The desktop UID must match the host owner of both the directory and
the files it uses. Use a private directory outside the checkout.

```bash
export WEBTOP_HOST_AUTH_DIR="$XDG_RUNTIME_DIR/webtop-auth"
install -d -m 700 "$WEBTOP_HOST_AUTH_DIR"
```

- **SSH agent.** Start a dedicated `ssh-agent -a "$WEBTOP_HOST_AUTH_DIR/ssh-agent.sock"`
  on the host and use that socket explicitly with `ssh-add` to load only keys
  intended for Webtop. Keep the socket mode at `0600`. The container receives
  access to signing operations through the socket.
- **Docker registry.** Optionally place a Docker `config.json` at
  `$WEBTOP_HOST_AUTH_DIR/docker/config.json`. Use directory mode `0700` and file
  mode `0600`. Include only `{"auths":{"ghcr.io":{"auth":"…"}}}`, where
  `auth` is the base64-encoded registry username and token separated by a colon.
  Set `WEBTOP_DOCKER_REGISTRY` to match if using a different registry. Use a
  token scoped to the required repository and operations. Treat the config as
  a credential. The overlay supplies registry credentials to compatible
  clients and leaves the Docker daemon disabled.

```bash
docker compose -f compose.yaml -f compose.host-auth.yaml up -d
```

The desktop startup exports `SSH_AUTH_SOCK` and/or `DOCKER_CONFIG` after
validating the opted-in resources. For a separate shell inside the Webtop
container, source `/usr/local/libexec/webtop/session-host-auth` as the desktop
user in Bash. Leave out either resource to enable only the other.

## Audio and desktop updates

The desktop and Selkies share the PipeWire graph under `/run/webtop/desktop`.
See the container log for audio service diagnostics. Set
`SELKIES_MICROPHONE_ENABLED=true` to make microphone forwarding available in
the browser sidebar. The browser still requires a trusted origin and permission.
Run `omarchy update` for host-side image replacement commands.

## Logs & Troubleshooting

- Profile and compositor logs are stored in the persistent `/config` home:
  - `webtop-config/.local/state/omarchy/logs/profile-init.log`
  - `webtop-config/.local/state/omarchy/logs/hyprland.log`
  - `webtop-config/.local/state/omarchy/logs/omarchy-shell.log`
