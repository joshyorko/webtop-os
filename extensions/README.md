# Webtop extensions

Place wallpapers under `backgrounds/<theme-slug>/`. Webtop exposes those files
to the native Omarchy picker after seeding. In a desktop terminal, run
`webtop-link-extensions` after adding filenames while the session is running.
Use `omarchy-theme-bg-switcher` to choose the active wallpaper. Add
`omarchy-menu.jsonc` at this directory's root to extend the native menu. Webtop
preserves a personal menu that differs from the built-in template. Run any
scripts stored here explicitly.
