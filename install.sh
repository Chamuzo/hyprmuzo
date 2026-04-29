#!/usr/bin/env bash
# hyprmuzo installer — clean Arch + Hyprland HyDE-style, no bloat
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="${HOME}"
CFG="${USER_HOME}/.config"
LOCAL_BIN="${USER_HOME}/.local/bin"
WALL_DIR="${USER_HOME}/Pictures/walls"
INSTALL_MODE=""
KERNEL_MODE=""
KEYBOARD_LAYOUT=""

log() { printf '\033[1;36m[hyprmuzo]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "Run as user, not root. sudo prompted when needed."
command -v pacman >/dev/null || die "Not Arch."

usage() {
  cat <<EOF
Usage: ./install.sh [--normal|--vm] [--kernel-normal|--kernel-g14] [--keyboard-es|--keyboard-us]

  --normal  Install normal Hyprland session
  --vm      Install VM-friendly session with software-render launch env
  --kernel-normal
            Install linux-hardened + headers
  --kernel-g14
            Do not install or change kernel packages
  --keyboard-es
            Use Spanish keyboard layout
  --keyboard-us
            Use US keyboard layout
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --normal) INSTALL_MODE="normal" ;;
    --vm) INSTALL_MODE="vm" ;;
    --kernel-normal) KERNEL_MODE="normal" ;;
    --kernel-g14|--g14) KERNEL_MODE="g14" ;;
    --keyboard-es|--es) KEYBOARD_LAYOUT="es" ;;
    --keyboard-us|--us) KEYBOARD_LAYOUT="us" ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

if [[ -z "$INSTALL_MODE" ]]; then
  printf '\nSelect install mode:\n'
  printf '  1) normal - bare metal / GPU configured by you\n'
  printf '  2) vm     - virtual machine, software-render launch env\n'
  read -r -p 'Mode [1/2]: ' mode_choice
  case "$mode_choice" in
    1|normal|NORMAL) INSTALL_MODE="normal" ;;
    2|vm|VM) INSTALL_MODE="vm" ;;
    *) die "Invalid mode." ;;
  esac
fi

log "Install mode: ${INSTALL_MODE}"

if [[ -z "$KERNEL_MODE" ]]; then
  printf '\nSelect kernel mode:\n'
  printf '  1) normal - install linux-hardened + headers\n'
  printf '  2) g14    - keep your existing ASUS G14 kernel untouched\n'
  read -r -p 'Kernel mode [1/2]: ' kernel_choice
  case "$kernel_choice" in
    1|normal|NORMAL) KERNEL_MODE="normal" ;;
    2|g14|G14) KERNEL_MODE="g14" ;;
    *) die "Invalid kernel mode." ;;
  esac
fi

log "Kernel mode: ${KERNEL_MODE}"

if [[ -z "$KEYBOARD_LAYOUT" ]]; then
  printf '\nSelect keyboard layout:\n'
  printf '  1) es - Spanish\n'
  printf '  2) us - US English\n'
  read -r -p 'Keyboard layout [1/2]: ' keyboard_choice
  case "$keyboard_choice" in
    1|es|ES|spanish|Spanish) KEYBOARD_LAYOUT="es" ;;
    2|us|US|eeuu|EEUU) KEYBOARD_LAYOUT="us" ;;
    *) die "Invalid keyboard layout." ;;
  esac
fi

log "Keyboard layout: ${KEYBOARD_LAYOUT}"

# --- 1. system update + base
log "Enable [multilib] repo (32-bit packages)"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  sudo sed -i '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' /etc/pacman.conf
fi

log "Sync repos + update"
sudo pacman -Syu --noconfirm

log "Install base build tools"
sudo pacman -S --needed --noconfirm base-devel git

# --- 2. yay (AUR helper)
if ! command -v yay >/dev/null; then
  log "Build yay"
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

# --- 3. packages
log "Install pacman + AUR packages"
mapfile -t PKGS < <(grep -v '^\s*#' "${REPO_DIR}/packages.txt" | grep -v '^\s*$')
if [[ "$KERNEL_MODE" == "normal" ]]; then
  PKGS+=(linux-hardened linux-hardened-headers linux-headers)
fi
yay -S --needed --noconfirm "${PKGS[@]}"

# --- 4. services
log "Enable services"
sudo systemctl enable --now ufw.service || true
sudo ufw default deny incoming || true
sudo ufw default allow outgoing || true
sudo ufw enable || true
sudo systemctl enable apparmor.service || true
sudo systemctl enable auditd.service || true
sudo systemctl enable bluetooth.service || true
sudo systemctl enable NetworkManager.service || true

# greetd config
log "Configure greetd (tuigreet)"
if [[ "$INSTALL_MODE" == "vm" ]]; then
  HYPRLAND_CMD='dbus-run-session env WLR_RENDERER_ALLOW_SOFTWARE=1 LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe Hyprland'
else
  HYPRLAND_CMD='dbus-run-session Hyprland'
fi

sudo tee /etc/greetd/config.toml >/dev/null <<EOF
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd '${HYPRLAND_CMD}'"
user = "greeter"
EOF
sudo systemctl enable greetd.service

# --- 5. dotfiles
log "Deploy configs to ${CFG}"
mkdir -p "$CFG" "$LOCAL_BIN" "$WALL_DIR" "${USER_HOME}/Pictures/Screenshots"
xdg-user-dirs-update 2>/dev/null || true

for d in hypr waybar rofi kitty swaync matugen yazi nvim; do
  rm -rf "${CFG}/${d}.bak"
  [[ -e "${CFG}/${d}" ]] && mv "${CFG}/${d}" "${CFG}/${d}.bak"
  cp -r "${REPO_DIR}/config/${d}" "${CFG}/${d}"
done

sed -i "s/^    kb_layout = .*/    kb_layout = ${KEYBOARD_LAYOUT}/" "${CFG}/hypr/hyprland.conf"
sed -i '/^    kb_options = /d' "${CFG}/hypr/hyprland.conf"

# colors.conf fallback so Hyprland source line never fails before first matugen run
if [[ ! -f "${CFG}/hypr/colors.conf" ]]; then
  cat > "${CFG}/hypr/colors.conf" <<'EOF'
$background = rgb(1c1b1f)
$on_background = rgb(e6e1e5)
$surface = rgb(2b292d)
$on_surface = rgb(c9c5ca)
$accent = rgb(c8bfff)
$on_accent = rgb(31298a)
EOF
fi

install -Dm755 "${REPO_DIR}/bin/themeswitch" "${LOCAL_BIN}/themeswitch"

# walls
cp -rn "${REPO_DIR}/walls/." "${WALL_DIR}/" 2>/dev/null || true

# --- 6. shell env defaults
BRC="${USER_HOME}/.bashrc"
touch "$BRC"
grep -q '.local/bin'  "$BRC" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BRC"
grep -q '^export EDITOR='  "$BRC" || echo 'export EDITOR=nvim'  >> "$BRC"
grep -q '^export VISUAL='  "$BRC" || echo 'export VISUAL=nvim'  >> "$BRC"
grep -q '^export BROWSER=' "$BRC" || echo 'export BROWSER=brave' >> "$BRC"
grep -q 'alias vi='        "$BRC" || echo 'alias vi=nvim; alias vim=nvim' >> "$BRC"

# wayland flags for electron apps (brave, vscodium)
cat > "${USER_HOME}/.config/electron-flags.conf" <<'EOF'
--enable-features=UseOzonePlatform,WaylandWindowDecorations
--ozone-platform=wayland
EOF
cp "${USER_HOME}/.config/electron-flags.conf" "${USER_HOME}/.config/brave-flags.conf"
cp "${USER_HOME}/.config/electron-flags.conf" "${USER_HOME}/.config/codium-flags.conf"

# --- 6a. system-wide dark mode (GTK3/4 + cursor + Qt platformtheme)
log "Configure dark mode (GTK + cursor + Qt)"
mkdir -p "${CFG}/gtk-3.0" "${CFG}/gtk-4.0"
cat > "${CFG}/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-font-name=JetBrainsMono Nerd Font 11
EOF
cp "${CFG}/gtk-3.0/settings.ini" "${CFG}/gtk-4.0/settings.ini"
ln -sf /usr/share/themes/adw-gtk3-dark "${CFG}/gtk-4.0/gtk-4.0" 2>/dev/null || true

# user dconf defaults (applied at login)
mkdir -p "${CFG}/dconf"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'  2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'  2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true

# --- 6b. xdg mimeapps defaults
log "Set xdg default apps (browser, editor, file mgr)"
mkdir -p "${CFG}"
cat > "${CFG}/mimeapps.list" <<'EOF'
[Default Applications]
text/html=brave-browser.desktop
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
x-scheme-handler/about=brave-browser.desktop
x-scheme-handler/unknown=brave-browser.desktop
text/plain=nvim.desktop
application/x-shellscript=nvim.desktop
inode/directory=yazi.desktop
EOF

xdg-mime default brave-browser.desktop x-scheme-handler/http  2>/dev/null || true
xdg-mime default brave-browser.desktop x-scheme-handler/https 2>/dev/null || true
xdg-mime default nvim.desktop          text/plain             2>/dev/null || true
xdg-mime default yazi.desktop          inode/directory        2>/dev/null || true

# yazi desktop entry (does not ship one by default)
if [[ ! -f /usr/share/applications/yazi.desktop ]]; then
  sudo tee /usr/share/applications/yazi.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Yazi
Exec=kitty -e yazi %f
Type=Application
Terminal=false
MimeType=inode/directory;
Icon=utilities-terminal
Categories=System;FileManager;
EOF
fi

# --- 7. first theme gen
log "Generate initial theme from default wall"
DEFAULT_WALL="$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' \) | head -n1 || true)"
if [[ -n "$DEFAULT_WALL" ]]; then
  mkdir -p "${CFG}/gtk-3.0" "${CFG}/gtk-4.0"
  cat > "${CFG}/hypr/hyprpaper.conf" <<EOF
preload = $DEFAULT_WALL
wallpaper = ,$DEFAULT_WALL
splash = false
EOF
  matugen image "$DEFAULT_WALL" || log "initial color generation failed; run themeswitch after logging into Hyprland"
fi

log "Done. Reboot, login via tuigreet → Hyprland."
log "Bind SUPER+T runs themeswitch <wall> — see hyprland.conf."
