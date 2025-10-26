#!/bin/bash
# Configuration
MAX_TITLE_LENGTH=26
MAX_ARTIST_LENGTH=16
CURL_TIMEOUT=6
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$HOME/.cache/eww/music-widget"
mkdir -p "$CACHE_DIR"

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
    # Check if playerctl is actually returning valid metadata
    local cover_url="$(playerctl metadata mpris:artUrl 2>/dev/null)"
    
    # If no cover URL, return empty
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
    
    # Get file extension from URL
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

# If called with "cover" argument, output cover path only
if [[ "$1" == "cover" ]]; then
    handle_cover_art
    exit 0
fi

# Get metadata
active_player="$(playerctl -l 2>/dev/null | head -n1)"
player_cache_file="$CACHE_DIR/active_player"
previous_player=""

# Read previous player if cache exists
if [[ -f "$player_cache_file" ]]; then
    previous_player="$(cat "$player_cache_file")"
fi

# Update cache with current player
echo "$active_player" > "$player_cache_file"

title="$(playerctl metadata title 2>/dev/null || echo "No song")"
artist="$(playerctl metadata artist 2>/dev/null || echo "")"
status="$(playerctl status 2>/dev/null | sed 's/Playing/󰏤/g; s/Paused/󰐊/g' || echo '⸻')"

# Get length from metadata (in microseconds)
raw_length="$(playerctl metadata mpris:length 2>/dev/null || echo 0)"
length=$((raw_length / 1000000))

# Get position - force fresh read from current player
position="$(playerctl position 2>/dev/null | awk '{printf("%d\n",$1)}' || echo 0)"

# If player changed, force position refresh by not using any cached value
if [[ "$active_player" != "$previous_player" ]] && [[ -n "$previous_player" ]]; then
    sleep 0.1
    position="$(playerctl position 2>/dev/null | awk '{printf("%d\n",$1)}' || echo 0)"
fi

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
    \"length\": \"$(format_time "$length")\",
    \"length_seconds\": $length,
    \"progress\": $progress,
    \"status\": \"$status\",
    \"cover\": \"$cover\"
}"
