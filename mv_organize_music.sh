#!/usr/bin/env bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# The source directory containing the files to organize
SOURCE=${1:-"./"}
# The destination directory for the organized files
DEST=${2:-"./organized"}
# Example usage: ./mv_organize_music.sh /path/to/source /path/to/destination

mkdir -p "$DEST"

sanitize() {
    echo "$1" | iconv -c -t UTF-8 | tr -d '\000' \
        | tr '/\\:*?"<>|`$!' '_' \
        | sed 's/[^[:print:]]//g' \
        | tr -s '_'
}

# Read all files (excluding those in DEST) into an array
SCRIPT_NAME=$(basename "$0")
FILES=()
while IFS= read -r -d '' file; do
  [[ "$(basename "$file")" == "$SCRIPT_NAME" ]] && continue
  FILES+=("$file")
done < <(find "$SOURCE" -type f ! -path "$DEST/*" -print0)

TOTAL=${#FILES[@]}
FAILURE_LOG=() # Initialize an empty array to log any failures

for i in "${!FILES[@]}"; do
    FILE="${FILES[$i]}"
    INDEX=$((i + 1))
    PERCENT=$((INDEX * 100 / TOTAL))
    
    echo "[${INDEX}/${TOTAL}] (${PERCENT}%) Processing: $(basename "$FILE")"
    
    ARTIST=$(ffprobe -v quiet -show_entries format_tags=artist \
        -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null || { FAILURE_LOG+=("Artist:$INDEX"); })
    ALBUM=$(ffprobe -v quiet -show_entries format_tags=album \
        -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null || { FAILURE_LOG+=("Album:$INDEX"); })
    TITLE=$(ffprobe -v quiet -show_entries format_tags=title \
        -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null || { FAILURE_LOG+=("Title:$INDEX"); })
        
    FILETYPE=$(file --brief --mime-type "$FILE" 2>/dev/null || true)

    # Set default values if metadata is missing
    [[ -z "$ARTIST" ]] && ARTIST="Unknown Artist"
    [[ -z "$ALBUM" ]] && ALBUM="Unknown Album"
    [[ -z "$TITLE" ]] && TITLE=$(basename "$FILE")

    if [[ "$FILETYPE" != audio/* ]]; then
        SAFE_ARTIST="not_audio"
        SAFE_ALBUM=$(date +%Y-%m-%d-%H-%M-%S-%N)
    else
        SAFE_ARTIST=$(sanitize "$ARTIST")
        SAFE_ALBUM=$(sanitize "$ALBUM")
    fi
    SAFE_TITLE=$(sanitize "$TITLE")

    DEST_DIR="${DEST%/}/$SAFE_ARTIST/$SAFE_ALBUM"
    mkdir -p "$DEST_DIR"

    EXT="${FILE##*.}"
    OUTFILE="$DEST_DIR/$SAFE_TITLE.$EXT"


    if [ "${#FAILURE_LOG[@]}" -ne 0 ]; then
        echo -e "\033[0;31mMetadata extraction failed for indices: ${FAILURE_LOG[*]}\033[0m"
    elif [ ! -f "$OUTFILE" ]; then
        mv -n "$FILE" "$OUTFILE"
        echo -e "\033[0;32m→ Moved: $FILE → $OUTFILE\033[0m"
    else
        echo "→ Skipped (already exists): $OUTFILE"
    fi

    echo
done

find "$SOURCE" "$DEST" -type d -empty -delete
if [ "${#FAILURE_LOG[@]}" -ne 0 ]; then
    printf '%s\n' "${FAILURE_LOG[@]}" | sort | uniq -c
fi
