#!/bin/bash
# import-music.sh - Automated beets import script for slskd downloads
# Run via cron to import newly downloaded music

set -e

# Configuration
DOWNLOADS_DIR="/downloads"
LOG_FILE="/config/cron-import.log"
PROCESSED_FILE="/config/processed_dirs.txt"
MAX_LOG_SIZE=10485760  # 10MB

# Ensure processed file exists
touch "$PROCESSED_FILE"

# Rotate log if too large
if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== Starting music import ==="

# Find music directories with audio files (modified in the last 24 hours for daily runs)
# Using find to locate directories containing audio files
IMPORT_DIRS=()

# Look for directories containing music files
while IFS= read -r -d $'\0' dir; do
    # Get the parent directory containing the music file
    parent_dir=$(dirname "$dir")
    
    # Check if this directory (or any parent up to DOWNLOADS_DIR) is already processed
    already_processed=false
    check_dir="$parent_dir"
    while [[ "$check_dir" != "$DOWNLOADS_DIR" ]] && [[ "$check_dir" != "/" ]]; do
        if grep -qxF "$check_dir" "$PROCESSED_FILE" 2>/dev/null; then
            already_processed=true
            break
        fi
        check_dir=$(dirname "$check_dir")
    done
    
    if [[ "$already_processed" == "false" ]]; then
        # Find the album-level directory (first child of downloads)
        album_dir="$parent_dir"
        while [[ "$(dirname "$album_dir")" != "$DOWNLOADS_DIR" ]] && [[ "$album_dir" != "$DOWNLOADS_DIR" ]]; do
            album_dir=$(dirname "$album_dir")
        done
        
        # Add if not already in list
        if [[ "$album_dir" != "$DOWNLOADS_DIR" ]] && [[ ! " ${IMPORT_DIRS[*]} " =~ " ${album_dir} " ]]; then
            IMPORT_DIRS+=("$album_dir")
        fi
    fi
done < <(find "$DOWNLOADS_DIR" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.ogg" -o -iname "*.opus" -o -iname "*.wav" -o -iname "*.aac" \) -mtime -1 -print0 2>/dev/null)

if [[ ${#IMPORT_DIRS[@]} -eq 0 ]]; then
    log "No new music directories found to import"
    log "=== Import complete (nothing to do) ==="
    exit 0
fi

log "Found ${#IMPORT_DIRS[@]} directories to import:"
for dir in "${IMPORT_DIRS[@]}"; do
    log "  - $dir"
done

# Import each directory
SUCCESS_COUNT=0
FAIL_COUNT=0

for dir in "${IMPORT_DIRS[@]}"; do
    log "Importing: $dir"
    
    if beet import --quiet "$dir" 2>&1 | tee -a "$LOG_FILE"; then
        log "Successfully imported: $dir"
        echo "$dir" >> "$PROCESSED_FILE"
        ((SUCCESS_COUNT++)) || true
    else
        log "WARNING: Issues importing: $dir (may need manual review)"
        ((FAIL_COUNT++)) || true
    fi
done

log "=== Import complete: $SUCCESS_COUNT succeeded, $FAIL_COUNT with issues ==="

# Clean up old entries from processed file (keep last 1000)
if [[ $(wc -l < "$PROCESSED_FILE") -gt 1000 ]]; then
    tail -500 "$PROCESSED_FILE" > "${PROCESSED_FILE}.tmp"
    mv "${PROCESSED_FILE}.tmp" "$PROCESSED_FILE"
fi
