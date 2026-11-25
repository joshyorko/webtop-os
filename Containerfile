# syntax=docker/dockerfile:1
FROM ghcr.io/linuxserver/baseimage-selkies:arch

ARG OMARCHY_VERSION=4.5.0
ARG OMARCHY_CHANNEL=stable

LABEL org.opencontainers.image.title="Omarchy Quattro RS Webtop" \
      org.opencontainers.image.description="Modern Omarchy 4.5 (Quattro RS) Arch + Hyprland + Quickshell desktop on Selkies Wayland" \
      org.opencontainers.image.version="${OMARCHY_VERSION}" \
      org.opencontainers.image.source="https://github.com/joshyorko/webtop-os"

# Stage Omarchy pacman configuration and bootstrap key first for layer caching.
COPY root/etc/pacman.conf /etc/pacman.conf
COPY root/etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
COPY root/usr/share/pacman/keyrings/omarchy-bootstrap.asc /usr/share/pacman/keyrings/omarchy-bootstrap.asc

RUN \
  echo "**** prepare container runtime dirs for omarchy-settings scriptlet ****" && \
  mkdir -p /run /run/lock && \
  chmod 0755 /run /run/lock && \
  chown root:root /run /run/lock && \
  echo "**** bootstrap pacman keyrings (Arch + Omarchy) ****" && \
  pacman-key --init && \
  pacman-key --populate archlinux && \
  pacman-key --add /usr/share/pacman/keyrings/omarchy-bootstrap.asc && \
  pacman-key --lsign-key 40DFB630FF42BCFFB047046CF0134EE680CAC571 && \
  pacman -Syu --noconfirm && \
  pacman -S --noconfirm --needed omarchy-keyring && \
  pacman-key --populate omarchy && \
  echo "**** install Omarchy ${OMARCHY_VERSION} (Quattro RS) + core apps + dev tooling ****" && \
  pacman -S --noconfirm --needed \
    omarchy \
    omarchy-settings \
    omarchy-themes-intros \
    hyprland \
    hyprland-guiutils \
    hyprland-preview-share-picker \
    omarchy-hyprland-titlebars \
    hyprpicker \
    hyprsunset \
    quickshell \
    owe \
    uwsm \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland \
    xdg-terminal-exec \
    xdg-user-dirs \
    gnome-keyring \
    libsecret \
    polkit-gnome \
    pipewire \
    wireplumber \
    wl-clipboard \
    wayfreeze \
    wayshare \
    tesseract-data-eng \
    grim \
    slurp \
    xorg-xhost \
    xorg-xsetroot \
    foot \
    nautilus \
    nautilus-python \
    sushi \
    evince \
    imv \
    mpv \
    mpv-mpris \
    omarchy-chromium-bin \
    omarchy-nvim \
    neovim \
    omacalc \
    omawrite \
    omasnap \
    aether \
    gliff \
    herdr \
    hype \
    monologue \
    signed \
    disktree-bin \
    ttfx \
    yaru-icon-theme \
    gnome-themes-extra \
    ttf-jetbrains-mono-nerd-basic \
    ttf-ia-writer \
    woff2-font-awesome \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    qt6-base \
    qt6-declarative \
    qt6-multimedia \
    qt6-svg \
    qt6-wayland \
    qt6-imageformats \
    bash-completion \
    zsh \
    bat \
    btop \
    eza \
    fastfetch \
    fd \
    fzf \
    git \
    git-lfs \
    github-cli \
    gum \
    inotify-tools \
    inxi \
    jq \
    lazygit \
    lazydocker \
    less \
    lua51 \
    luarocks \
    mise-bin \
    pamixer \
    ripgrep \
    socat \
    starship \
    tldr \
    tmux \
    tobi-try \
    tree-sitter-cli \
    unzip \
    usage \
    yay \
    zoxide \
    clang \
    cmake \
    gdb \
    postgresql-libs \
    aws-cli-v2 \
    ansible \
    minio-client && \
  echo "**** apply Omarchy container-safe system tweaks ****" && \
  if [ -f /usr/share/omarchy/install/config/theme-system.sh ]; then \
    bash /usr/share/omarchy/install/config/theme-system.sh; \
  fi && \
  if [ -x /usr/bin/Hyprland ]; then \
    setcap -r /usr/bin/Hyprland 2>/dev/null || true; \
  fi && \
  if [ -x /usr/bin/chromium ] && [ ! -L /usr/bin/chromium ]; then \
    mv /usr/bin/chromium /usr/bin/chromium-real && \
    ln -s /usr/local/bin/wrapped-chromium /usr/bin/chromium; \
  fi && \
  rm -f /usr/share/dbus-1/system-services/org.freedesktop.UDisks2.service && \
  echo "**** cleanup caches ****" && \
  rm -rf \
    /config/.cache \
    /tmp/* \
    /var/cache/pacman/pkg/* \
    /var/lib/pacman/sync/*

# Bake latest action-server (joshyorko/actions) and rcc (joshyorko/rcc).
RUN \
  echo "**** install action-server and rcc from joshyorko releases ****" && \
  ACTION_SERVER_URL=$( \
    curl -fsSL "https://api.github.com/repos/joshyorko/actions/releases?per_page=20" 2>/dev/null \
      | jq -r '[.[] | select(.prerelease == false and (.tag_name | startswith("action-server-")))] | .[0].assets[] | select(.name == "action-server-linux64") | .browser_download_url' \
      | head -n 1 || true \
  ) && \
  ACTION_SERVER_URL="${ACTION_SERVER_URL:-https://github.com/joshyorko/actions/releases/download/action-server-v1.2.6/action-server-linux64}" && \
  curl -fsSL "${ACTION_SERVER_URL}" -o /usr/local/bin/action-server && \
  chmod 0755 /usr/local/bin/action-server && \
  curl -fsSL "https://github.com/joshyorko/rcc/releases/latest/download/rcc-linux64" -o /usr/local/bin/rcc && \
  chmod 0755 /usr/local/bin/rcc

# Bake a clean, credential-free Kasm-style default profile template outside /config.
RUN \
  echo "**** create pinned /defaults/omarchy-profile template ****" && \
  rm -rf /defaults/omarchy-profile && \
  mkdir -p /defaults/omarchy-profile/.config/hypr && \
  cp -a /etc/skel/. /defaults/omarchy-profile/ && \
  rm -f \
    /defaults/omarchy-profile/.config/autostart/limine-snapper-notify.desktop \
    /defaults/omarchy-profile/.config/autostart/print-applet.desktop && \
  printf '%s\n' \
    '-- Container monitor defaults (overridable via OMARCHY_MODE / OMARCHY_SCALE / OMARCHY_GDK_SCALE or direct edits).' \
    'local omarchy_monitor_mode = os.getenv("OMARCHY_MODE") or "1920x1080@60"' \
    'local omarchy_monitor_scale = os.getenv("OMARCHY_SCALE") or "1"' \
    'hl.monitor({ output = "", mode = omarchy_monitor_mode, position = "auto", scale = omarchy_monitor_scale })' \
    '' \
    'local omarchy_gdk_scale = tonumber(os.getenv("OMARCHY_GDK_SCALE") or "") or 1' \
    'hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))' \
    > /defaults/omarchy-profile/.config/hypr/monitors.lua && \
  pacman -Q omarchy > /defaults/omarchy-profile.version && \
  chown -R root:root /defaults/omarchy-profile /defaults/omarchy-profile.version && \
  chmod -R a+rX,go-w /defaults/omarchy-profile && \
  chmod 0644 /defaults/omarchy-profile.version

# Cloud-native unprivileged runtime defaults placed after heavy package layers.
ENV WEBTOP_USER=kdlocpanda \
    WEBTOP_GIT_NAME=joshyorko \
    TITLE="Omarchy Quattro RS" \
    PIXELFLUX_WAYLAND=true \
    OMARCHY_PATH=/usr/share/omarchy \
    OMARCHY_MODE=1920x1080@60 \
    OMARCHY_SCALE=1 \
    OMARCHY_GDK_SCALE=1 \
    SELKIES_WAYLAND_SOCKET_INDEX=2 \
    UPDATE_ACTIONS_TOOLS=false \
    START_DOCKER=false \
    NO_GAMEPAD=true \
    NO_WEBCAM=true \
    PATH="/usr/local/bin:/usr/share/omarchy/bin:/lsiopy/bin:/usr/local/sbin:/usr/bin:/bin"

# Overlay container shims, Wayland startup, init hooks, and pacman config.
COPY root/ /
COPY webtop-inject-scripts/ /custom-cont-init.d/

# Match the service account exactly even when a desktop alias is present.
RUN sed -i 's/grep abc \/etc\/passwd/grep "^abc:" \/etc\/passwd/' /etc/s6-overlay/s6-rc.d/init-adduser/run && \
    printf '%s\n' '/usr/local/bin/omarchy-desktop-user' >> /etc/s6-overlay/s6-rc.d/init-adduser/run && \
    mkdir -p /usr/local/lib && \
    gcc -shared -fPIC -O2 -Wall -Wextra \
      -o /usr/local/lib/libgbm_modifier_guard.so \
      /usr/local/src/gbm-modifier-guard.c -ldl && \
    gcc -shared -fPIC -O2 -Wall -Wextra \
      -o /usr/local/lib/libwayland_xdg_sync.so \
      /usr/local/src/wayland-xdg-sync.c -lwayland-client -ldl && \
    chmod 0755 \
      /usr/local/lib/libgbm_modifier_guard.so \
      /usr/local/lib/libwayland_xdg_sync.so && \
    chmod +x \
      /defaults/startwm_wayland.sh \
      /etc/cont-init.d/40-omarchy-init \
      /usr/local/bin/omarchy-init-home \
      /usr/local/bin/omarchy-desktop-user \
      /usr/local/bin/selkies \
      /usr/local/bin/systemd-cat \
      /usr/local/bin/uwsm-app \
      /usr/local/bin/systemd-run \
      /usr/local/bin/wrapped-chromium \
      /custom-cont-init.d/*.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -fsS http://127.0.0.1:3000/ >/dev/null || exit 1

EXPOSE 3000 3001
VOLUME /config
