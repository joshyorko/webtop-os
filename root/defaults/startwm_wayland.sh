#!/bin/bash
# Start Omarchy 4.5 (Quattro RS) Hyprland + Quickshell nested on Selkies/Pixelflux Wayland.

ulimit -c 0
setterm blank 0 2>/dev/null || true
setterm powerdown 0 2>/dev/null || true

export HOME="${HOME:-/config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.XDG}"
mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state/omarchy/logs" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Keep container shims (/usr/local/bin) ahead of /usr/bin so systemd-cat/uwsm-app/systemd-run work without PID 1 systemd.
export PATH="/usr/local/bin:/usr/share/omarchy/bin:/lsiopy/bin:/usr/local/sbin:/usr/bin:/bin"
export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

if [[ -r "$OMARCHY_PATH/default/bash/env-bootstrap" ]]; then
  # shellcheck disable=SC1091
  source "$OMARCHY_PATH/default/bash/env-bootstrap"
fi
if [[ -r "$OMARCHY_PATH/default/uwsm/default" ]]; then
  # shellcheck disable=SC1091
  source "$OMARCHY_PATH/default/uwsm/default"
fi

# Re-assert container shim priority after env-bootstrap/uwsm sourcing.
_clean_path="/usr/local/bin"
IFS=: read -ra _path_parts <<< "${PATH:-}"
for _p in "${_path_parts[@]}"; do
  [[ -n "$_p" && "$_p" != "/usr/local/bin" ]] && _clean_path="$_clean_path:$_p"
done
export PATH="$_clean_path"
unset _clean_path _path_parts _p

export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export GDK_BACKEND="wayland,x11,*"
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-gtk3}"
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export OZONE_PLATFORM=wayland
export MOZ_ENABLE_WAYLAND=1
export XCURSOR_THEME="${XCURSOR_THEME:-Adwaita}"
export XCURSOR_SIZE="${XCURSOR_SIZE:-24}"
export HYPRCURSOR_SIZE="${HYPRCURSOR_SIZE:-24}"
export XKB_DEFAULT_LAYOUT="${XKB_DEFAULT_LAYOUT:-us}"
export XKB_DEFAULT_RULES="${XKB_DEFAULT_RULES:-evdev}"

# Strip Selkies LD_PRELOAD interposers before running Hyprland, PipeWire, and Quickshell.
unset LD_PRELOAD

# Fast-path no-op when already initialized; safely retries if cont-init was incomplete.
/usr/local/bin/omarchy-init-home || exit "$?"

# Cloud-native rendering: use hardware DRI only when accessible, otherwise cgroup-scaled llvmpipe.
HAS_GPU=0
for node in /dev/dri/renderD* /dev/nvidia0; do
  if [[ -r "$node" ]]; then
    HAS_GPU=1
    break
  fi
done

if (( ! HAS_GPU )); then
  CPU_SHARE=$(nproc 2>/dev/null || echo 2)
  if read -r QUOTA PERIOD </sys/fs/cgroup/cpu.max 2>/dev/null && [[ "$QUOTA" != "max" && "$PERIOD" -gt 0 ]]; then
    CPU_SHARE=$(( (QUOTA + PERIOD - 1) / PERIOD ))
  elif [[ -r /sys/fs/cgroup/cpu/cpu.cfs_quota_us && -r /sys/fs/cgroup/cpu/cpu.cfs_period_us ]]; then
    QUOTA=$(</sys/fs/cgroup/cpu/cpu.cfs_quota_us)
    PERIOD=$(</sys/fs/cgroup/cpu/cpu.cfs_period_us)
    if [[ "$QUOTA" -gt 0 && "$PERIOD" -gt 0 ]]; then
      CPU_SHARE=$(( (QUOTA + PERIOD - 1) / PERIOD ))
    fi
  fi
  (( CPU_SHARE < 1 )) && CPU_SHARE=1
  (( CPU_SHARE > 8 )) && CPU_SHARE=8

  export LP_NUM_THREADS="${LP_NUM_THREADS:-$CPU_SHARE}"
  export LIBGL_ALWAYS_SOFTWARE=1
  export WLR_RENDERER_ALLOW_SOFTWARE=1
  export AQ_NO_MODIFIERS=1
  export GALLIUM_DRIVER=llvmpipe
  echo "[startwm] WARNING: No accessible /dev/dri/renderD* node found; Hyprland/Aquamarine requires a DRM render node (host /dev/dri, virtio-gpu, or vkms)." >&2
  echo "[startwm] Headless fallback env configured: Mesa llvmpipe (${LP_NUM_THREADS} threads)"
fi

# Pixelflux exposes the parent Smithay Wayland socket (normally wayland-1).
PARENT_WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export AQ_BACKEND=wayland

start_omarchy_session() {
  export WAYLAND_DISPLAY="$PARENT_WAYLAND_DISPLAY"

  if command -v pipewire >/dev/null 2>&1; then
    pipewire >"$HOME/.local/state/omarchy/logs/pipewire.log" 2>&1 &
    PIPEWIRE_PID=$!
    for _ in $(seq 1 50); do
      [[ -S "$XDG_RUNTIME_DIR/pipewire-0" ]] && break
      sleep 0.1
    done
    if command -v wireplumber >/dev/null 2>&1; then
      wireplumber >"$HOME/.local/state/omarchy/logs/wireplumber.log" 2>&1 &
      WIREPLUMBER_PID=$!
    fi
  fi

  if command -v gnome-keyring-daemon >/dev/null 2>&1; then
    eval "$(gnome-keyring-daemon --start --components=secrets 2>/dev/null)" || true
    export GNOME_KEYRING_CONTROL SSH_AUTH_SOCK
  fi

  HYPR_PRELOAD=""
  if [[ -r /usr/local/lib/libwayland_xdg_sync.so ]]; then
    HYPR_PRELOAD="/usr/local/lib/libwayland_xdg_sync.so"
  fi
  LD_PRELOAD="$HYPR_PRELOAD" WAYLAND_DISPLAY="$PARENT_WAYLAND_DISPLAY" AQ_BACKEND=wayland \
    Hyprland >"$HOME/.local/state/omarchy/logs/hyprland.log" 2>&1 &
  HYPR_PID=$!
  trap 'kill "$HYPR_PID" 2>/dev/null || true; wait "$HYPR_PID" 2>/dev/null || true' TERM INT
  wait "$HYPR_PID"
  STATUS=$?
  trap - TERM INT

  [[ -n "${WIREPLUMBER_PID:-}" ]] && kill "$WIREPLUMBER_PID" 2>/dev/null || true
  [[ -n "${PIPEWIRE_PID:-}" ]] && kill "$PIPEWIRE_PID" 2>/dev/null || true
  return "$STATUS"
}

export PARENT_WAYLAND_DISPLAY
export -f start_omarchy_session

exec dbus-run-session bash -c 'start_omarchy_session'
