#!/bin/sh
WALL_DIR="$HOME/.config/hypr/wallpapers"
THEME="$HOME/.config/rofi/wallpaper.rasi"

# exit if no wallpapers
[ ! -d "$WALL_DIR" ] && exit 0

# build rofi menu with proper null-separated format
choice=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0 |
while IFS= read -r -d '' img; do
    name=$(basename "$img")
    printf "%s\0icon\x1f%s\n" "$name" "$img"
done | rofi -dmenu -show-icons -theme "$THEME" -p "Wallpaper" -i)

# exit if nothing selected
[ -z "$choice" ] && exit 0

# set wallpaper
awww img "$WALL_DIR/$choice" --transition-type grow
