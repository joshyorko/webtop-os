#!/usr/bin/env bash
set -euo pipefail

(( EUID == 0 )) || { echo 'Run with sudo to test real UID migration.' >&2; exit 1; }
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
chmod 0755 "$scratch"
home=$scratch/config
mkdir -p "$home/.config/hypr" "$home/.cache" "$scratch/outside"
printf 'my theme\n' > "$home/.config/hypr/theme"
printf 'private\n' > "$home/other-user"
chown -R 911:911 "$home/.config"
chown 2000:2000 "$home/other-user"
ln -s "$scratch/outside" "$home/external"

"$repo/root/usr/local/libexec/webtop/prepare-home" "$home" 1000 1000 911
[[ $(stat -c '%u:%g:%a' "$home") == 1000:1000:700 ]]
[[ $(stat -c '%u:%g' "$home/.config/hypr/theme") == 1000:1000 ]]
[[ $(stat -c '%u' "$home/.cache") == 1000 ]]
[[ $(stat -c '%u' "$home/other-user") == 2000 ]]
[[ $(stat -c '%u' "$scratch/outside") == 0 ]]
setpriv --reuid 1000 --regid 1000 --clear-groups sh -c \
  'printf "edited theme\n" > "$1/.config/hypr/theme"; touch "$1/.cache/writable"' sh "$home"
"$repo/root/usr/local/libexec/webtop/prepare-home" "$home" 1000 1000 911
[[ $(cat "$home/.config/hypr/theme") == 'edited theme' ]]
[[ $(stat -c '%u' "$home/other-user") == 2000 ]]
[[ $(stat -c '%u' "$scratch/outside") == 0 ]]
printf 'ok - seeded ownership migrates, user edits survive retries, external links and other users stay unchanged\n'
