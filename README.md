# hyprmuzo

Minimal HyDE-aesthetic Hyprland setup for Arch. No bloat.
~15 packages vs HyDE's 80+. Wallpaper-driven theming via matugen.

## What's in

- Hyprland + hyprlock + hypridle + swww
- Waybar, Rofi, Kitty, swaync, Yazi
- Matugen → wall in, full theme out (waybar, kitty, rofi, swaync, gtk, hyprland borders)
- Hardened base: ufw, apparmor, audit, linux-hardened, greetd+tuigreet
- One script: `themeswitch <wall>` reloads everything

## Pre-install (Arch base)

Assumes you already have:

- Arch installed with LUKS+btrfs (use `archinstall` "minimal" profile, no DE)
- A regular user with sudo
- Network up
- Booted into TTY (not a DE)

## Install

```bash
git clone https://github.com/chamuzo/hyprmuzo.git
cd hyprmuzo
chmod +x install.sh bin/themeswitch
./install.sh
```

Drop wallpapers into `~/Pictures/walls/` then reboot.
Login via tuigreet → Hyprland.

## Keys

| Key | Action |
|---|---|
| `SUPER + Q` | kitty terminal |
| `SUPER + E` | yazi file mgr |
| `SUPER + B` | brave browser |
| `SUPER + N` | neovim |
| `SUPER + I` | vscodium |
| `SUPER + R` | rofi launcher |
| `SUPER + Escape` | close window |
| `SUPER + SHIFT + Escape` | exit hyprland |
| `SUPER + L` | lock |
| `SUPER + T` | random theme switch |
| `SUPER + SHIFT + T` | pick wallpaper via rofi |
| `SUPER + C` | clipboard history |
| `Print` / `SUPER+Print` | screenshot region/output |

## Theme

`themeswitch <wall.jpg>` does:

1. `swww img` set wallpaper
2. `matugen image` regenerate Material You palette
3. Templates render → `colors.{conf,css,rasi}` files
4. Reload waybar, kitty, hyprland, swaync

Add walls to `~/Pictures/walls/`. That's it.

## Hardening notes

- ufw: deny incoming, allow outgoing
- apparmor + auditd enabled
- LUKS root assumed from archinstall step
- greetd-tuigreet replaces SDDM (lighter, no Qt6 in login path)
- Run `linux-hardened` kernel by default — add as fallback in bootloader

## Uninstall / restore

`install.sh` backs up existing configs to `~/.config/<app>.bak`. To revert:

```bash
for d in hypr waybar rofi kitty swaync matugen; do
  rm -rf ~/.config/$d && mv ~/.config/$d.bak ~/.config/$d
done
```

## Layout

```
hyprmuzo/
├── install.sh         # bootstrap whole system
├── packages.txt       # pacman + AUR list
├── bin/themeswitch    # theme reload script
├── config/            # all dotfiles, deploy to ~/.config
└── walls/             # default wallpapers
```

## License

MIT. Steal freely.
