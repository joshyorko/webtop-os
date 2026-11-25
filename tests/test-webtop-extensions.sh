#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
seed="$repo/root/usr/local/bin/webtop-seed-extensions"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT

defaults="$scratch/defaults"
extensions="$scratch/profile/webtop-extensions"
mkdir -p "$defaults/assets" "$scratch/profile"
printf 'starter\n' > "$defaults/assets/wallpaper.txt"
printf 'hidden\n' > "$defaults/.example"
printf 'keep theme\n' > "$scratch/profile/current-theme"

"$seed" "$defaults" "$extensions"
cmp "$defaults/assets/wallpaper.txt" "$extensions/assets/wallpaper.txt"
cmp "$defaults/.example" "$extensions/.example"
printf 'ok - first boot seeds nested and hidden defaults\n'

printf 'my wallpaper\n' > "$extensions/assets/wallpaper.txt"
printf 'updated starter\n' > "$defaults/assets/wallpaper.txt"
printf 'new seed\n' > "$defaults/assets/new.txt"
rm -- "$defaults/.example"
"$seed" "$defaults" "$extensions"
[[ $(cat "$extensions/assets/wallpaper.txt") == 'my wallpaper' ]]
[[ $(cat "$extensions/.example") == 'hidden' ]]
[[ $(cat "$scratch/profile/current-theme") == 'keep theme' ]]
cmp "$defaults/assets/new.txt" "$extensions/assets/new.txt"
printf 'ok - replacement adds new files and preserves edits, retired files, and profile state\n'

mkdir -p "$scratch/outside" "$defaults/linked" "$defaults/occupied"
ln -s "$scratch/outside" "$extensions/linked"
ln -s "$scratch/absent" "$extensions/dangling"
ln -s "$scratch/outside" "$defaults/source-link"
printf 'seed\n' > "$defaults/linked/entry"
printf 'seed\n' > "$defaults/dangling"
printf 'seed\n' > "$defaults/occupied/entry"
printf 'keep file\n' > "$extensions/occupied"
"$seed" "$defaults" "$extensions"
[[ -L "$extensions/linked" && -L "$extensions/dangling" ]]
[[ ! -e "$scratch/outside/entry" && ! -e "$scratch/absent" ]]
[[ ! -e "$extensions/source-link" && ! -L "$extensions/source-link" ]]
[[ $(cat "$extensions/occupied") == 'keep file' ]]
ln -s "$scratch/outside" "$scratch/redirect"
"$seed" "$defaults" "$scratch/redirect"
[[ -z $(ls -A -- "$scratch/outside") ]]
printf 'ok - symlinks and occupied paths are left alone\n'

parallel="$scratch/parallel"
"$seed" "$defaults" "$parallel" &
first=$!
"$seed" "$defaults" "$parallel" &
second=$!
wait "$first"
wait "$second"
cmp "$defaults/assets/wallpaper.txt" "$parallel/assets/wallpaper.txt"
[[ -z $(find "$parallel" -name '.webtop-seed.*' -print -quit) ]]
printf 'ok - concurrent seed attempts publish complete files and clean up staging\n'

# The upstream picker and wallpaper cycler enumerate user backgrounds with find -L.
live="$scratch/checkout/extensions"
theme=tokyo-night
consumer="$scratch/profile/.config/omarchy/backgrounds/$theme"
link_extensions="$repo/root/usr/local/bin/webtop-link-extensions"
mkdir -p "$live/backgrounds/$theme" "$consumer"
printf 'original pixels\n' > "$live/backgrounds/$theme/Wallpaper.PNG"
printf 'tracked extension\n' > "$live/README.md"
printf 'colliding extension wallpaper\n' > "$live/backgrounds/$theme/keep.png"
printf 'existing user wallpaper\n' > "$consumer/keep.png"
ln -s "$scratch/outside" "$live/backgrounds/$theme/skip.png"
git -C "$scratch/checkout" init -q
git -C "$scratch/checkout" add extensions
git -C "$scratch/checkout" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture

HOME="$scratch/profile" "$link_extensions" "$live"
[[ $(find -L "$consumer" -maxdepth 1 -type f -name Wallpaper.PNG) == "$consumer/Wallpaper.PNG" ]]
[[ $(cat "$consumer/keep.png") == 'existing user wallpaper' && ! -L "$consumer/skip.png" ]]
printf 'replacement pixels\n' > "$live/backgrounds/$theme/new"
mv -f "$live/backgrounds/$theme/new" "$live/backgrounds/$theme/Wallpaper.PNG"
[[ $(cat "$consumer/Wallpaper.PNG") == 'replacement pixels' ]]
[[ $(git -C "$scratch/checkout" status --short) == ' M extensions/backgrounds/tokyo-night/Wallpaper.PNG' ]]
printf 'ok - Omarchy background path sees atomic tracked wallpaper replacement\n'


menu_consumer="$scratch/profile/.config/omarchy/extensions/omarchy-menu.jsonc"
printf '{"personal":{"label":"Tracked menu"}}\n' > "$live/omarchy-menu.jsonc"
HOME="$scratch/profile" "$link_extensions" "$live"
[[ $(readlink "$menu_consumer") == "$live/omarchy-menu.jsonc" ]]
printf '{"personal":{"label":"Updated menu"}}\n' > "$live/new-menu"
mv -f "$live/new-menu" "$live/omarchy-menu.jsonc"
cmp "$menu_consumer" "$live/omarchy-menu.jsonc"
rm "$menu_consumer"
printf '{"personal":{"label":"Private menu"}}\n' > "$menu_consumer"
HOME="$scratch/profile" "$link_extensions" "$live"
[[ ! -L "$menu_consumer" && $(cat "$menu_consumer") == '{"personal":{"label":"Private menu"}}' ]]
printf 'ok - native menu sees updates and preserves a personal override\n'
