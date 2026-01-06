#!/bin/bash
# Configuration
MAX_TITLE_LENGTH=26
MAX_ARTIST_LENGTH=16
CURL_TIMEOUT=6
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$HOME/.cache/eww/music-widget"
mkdir -p "$CACHE_DIR"

# Clean old covers (keep last 20 to prevent disk bloat)
find "$CACHE_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" \) -printf '%T@ %p\n' 2>/dev/null | 
  sort -rn | tail -n +21 | cut -d' ' -f2- | xargs -r rm 2>/dev/null

# Format seconds to MM:SS or HH:MM:SS
format_time() {
    local seconds=$1
    if [[ -z "$seconds" || "$seconds" == "null" || "$seconds" == "0" ]]; then
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
    local cover_url="$(playerctl metadata mpris:artUrl 2>/dev/null)"
    
    if [[ -z "$cover_url" ]]; then
        echo ""
        return
    fi
    
    # If it's a local file, decode and use it directly
    if [[ "$cover_url" == file://* ]]; then
        local local_path=$(printf '%b' "${cover_url#file://}")
        if [[ -f "$local_path" ]]; then
            echo "file://$local_path"
            return
        else
            echo ""
            return
        fi
    fi
    
    # For web URLs, hash the URL for caching
    local url_hash=$(echo -n "$cover_url" | md5sum | awk '{print $1}')
    local extension="${cover_url##*.}"
    if [[ "$extension" == "$cover_url" ]] || [[ ${#extension} -gt 4 ]]; then
        extension="jpg"
    fi
    
    local cached_cover="$CACHE_DIR/$url_hash.$extension"
    
    # If not cached, download it
    if [[ ! -f "$cached_cover" ]]; then
        if curl -s -L --max-time "$CURL_TIMEOUT" "$cover_url" -o "$cached_cover" 2>/dev/null; then
            if [[ -s "$cached_cover" ]] && file "$cached_cover" 2>/dev/null | grep -qE 'image|jpeg|png|jpg|gif'; then
                echo "file://$cached_cover"
                return
            else
                rm -f "$cached_cover"
            fi
        else
            rm -f "$cached_cover"
        fi
    else
        echo "file://$cached_cover"
        return
    fi
    echo ""
}

# Check if any player is available and active
if ! command -v playerctl >/dev/null 2>&1; then
    echo '{"title":"No playerctl","artist":"","position":"0:00","position_seconds":0,"length":"0:00","length_seconds":0,"progress":0,"status":"⏸","cover":""}'
    exit 0
fi

# Get list of active players
active_players="$(playerctl -l 2>/dev/null)"

if [[ -z "$active_players" ]]; then
    echo '{"title":"No song","artist":"","position":"0:00","position_seconds":0,"length":"0:00","length_seconds":0,"progress":0,"status":"⏸","cover":""}'
    exit 0
fi

# If called with "cover" argument, output cover path only
if [[ "$1" == "cover" ]]; then
    handle_cover_art
    exit 0
fi

# Get metadata - use specific player if multiple exist
title="$(playerctl metadata title 2>/dev/null)"
artist="$(playerctl metadata artist 2>/dev/null)"
status_raw="$(playerctl status 2>/dev/null)"

# If no title, no music is playing
if [[ -z "$title" ]]; then
    echo '{"title":"No song","artist":"","position":"0:00","position_seconds":0,"length":"0:00","length_seconds":0,"progress":0,"status":"⏸","cover":""}'
    exit 0
fi

# Convert status to icon
case "$status_raw" in
    "Playing")
        status=""  # Play icon
        ;;
    "Paused")
        status=""  # Pause icon
        ;;
    *)
        status=""  # Default pause
        ;;
esac

# Get length from metadata (in microseconds)
raw_length="$(playerctl metadata mpris:length 2>/dev/null || echo 0)"
length=$((raw_length / 1000000))

# Get position
position="$(playerctl position 2>/dev/null | awk '{printf("%d\n",$1)}' || echo 0)"

# Validate position doesn't exceed length
if [[ $position -gt $length ]] && [[ $length -gt 0 ]]; then
    position=$length
fi

# If position is negative or invalid, set to 0
if [[ $position -lt 0 ]]; then
    position=0
fi

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
    \"position_seconds\": $position,
    \"length\": \"$(format_time "$length")\",
    \"length_seconds\": $length,
    \"progress\": $progress,
    \"status\": \"$status\",
    \"cover\": \"$cover\"
}"
