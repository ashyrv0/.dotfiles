#!/bin/bash
# Configuration
MAX_TITLE_LENGTH=25
MAX_ARTIST_LENGTH=15
CURL_TIMEOUT=5

# Format seconds to MM:SS or HH:MM:SS
format_time() {
    local seconds=$1
    if [[ -z "$seconds" || "$seconds" == "null" || "$seconds" == "0.0" ]]; then
        echo "0:00"
        return
    fi
    seconds=$(echo "$seconds" | grep -oE '^[0-9]+' || echo "0")
    if [[ "$seconds" -le 0 ]]; then
        echo "0:00"
        return
    fi
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    if [[ "$hours" -gt 0 ]]; then
        printf "%d:%02d:%02d" "$hours" "$minutes" "$secs"
    else
        printf "%d:%02d" "$minutes" "$secs"
    fi
}

# Escape JSON strings properly
escape_json() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

# Truncate strings
truncate_string() {
    local string="$1"
    local max_length="$2"
    if [[ ${#string} -gt $max_length ]]; then
        echo "${string:0:$((max_length-3))}..."
    else
        echo "$string"
    fi
}

# Handle cover art
handle_cover_art() {
    local TMP_DIR="$HOME/.cache/eww"
    local TMP_COVER_PATH="$TMP_DIR/cover.png"
    local TMP_TEMP_PATH="$TMP_DIR/temp.png"
    [[ ! -d "$TMP_DIR" ]] && mkdir -p "$TMP_DIR"
    
    local ART_FROM_SPOTIFY="$(playerctl -p %any,spotify metadata mpris:artUrl 2>/dev/null | sed -e 's/open.spotify.com/i.scdn.co/g')"
    local ART_FROM_BROWSER="$(playerctl -p %any,mpd,firefox,chromium,brave metadata mpris:artUrl 2>/dev/null | sed -e 's/file:\/\///g')"
    
    if [[ -n "$ART_FROM_SPOTIFY" ]]; then
        curl -s --max-time "$CURL_TIMEOUT" "$ART_FROM_SPOTIFY" --output "$TMP_TEMP_PATH" 2>/dev/null && cp "$TMP_TEMP_PATH" "$TMP_COVER_PATH"
    elif [[ -n "$ART_FROM_BROWSER" ]] && [[ -f "$ART_FROM_BROWSER" ]]; then
        cp "$ART_FROM_BROWSER" "$TMP_TEMP_PATH"
        cp "$TMP_TEMP_PATH" "$TMP_COVER_PATH"
    fi
    echo "file://$TMP_COVER_PATH"
}

# If called with "cover" argument, output cover path only
if [[ "$1" == "cover" ]]; then
    handle_cover_art
    exit 0
fi

# Get metadata
title="$(playerctl metadata title 2>/dev/null || echo "No song")"
artist="$(playerctl metadata artist 2>/dev/null || echo "")"
status="$(playerctl status 2>/dev/null | sed 's/Playing/󰏤/g; s/Paused/󰐊/g' || echo '⸻')"
raw_length="$(playerctl metadata mpris:length 2>/dev/null || echo 0)"
length=$((raw_length / 1000000))
position="$(playerctl position 2>/dev/null | awk '{printf("%d\n",$1)}' || echo 0)"
cover="$(handle_cover_art)"

# Calculate progress %
progress=0
if [[ $length -gt 0 ]]; then
    progress=$((position * 100 / length))
fi

# Clean the strings before JSON encoding
clean_title="$(truncate_string "$title" $MAX_TITLE_LENGTH)"
clean_artist="$(truncate_string "$artist" $MAX_ARTIST_LENGTH)"

# Output JSON for Eww
echo "{
\"title\": \"$(escape_json "$clean_title")\",
\"artist\": \"$(escape_json "$clean_artist")\",
\"position\": \"$(format_time "$position")\",
\"length\": \"$(format_time "$length")\",
\"length_seconds\": $length,
\"progress\": $progress,
\"status\": \"$status\",
\"cover\": \"$cover\"
}"
