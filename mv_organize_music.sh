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
MOVED=0
NOT_AUDIO=0
FILE_TYPES=()
FAILURE_LOG=() # Initialize an empty array to log any failures

for i in "${!FILES[@]}"; do
    FILE="${FILES[$i]}"
    INDEX=$((i + 1))
    PERCENT=$((INDEX * 100 / TOTAL))
    
    echo "[${INDEX}/${TOTAL}] (${PERCENT}%) Processing: $(basename "$FILE")"
    
    FILETYPE=$(file --brief --mime-type "$FILE" 2>/dev/null || true)
    FILE_TYPES+=("$FILETYPE")
    
    if [[ "$FILETYPE" != audio/* ]]; then
        NOT_AUDIO=$((NOT_AUDIO + 1))
        SAFE_ARTIST="not_audio"
        SAFE_ALBUM=$(date +%Y-%m-%d-%H-%M-%S-%N)
    else
        METADATA=$(ffprobe -v quiet -show_entries format_tags=artist,album,title \
            -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null)
        IFS=$'\n' read -rd '' ARTIST ALBUM TITLE <<< "$METADATA" || {
            [[ -z "$ARTIST" ]] && { ARTIST="Unknown Artist"; FAILURE_LOG+=("Artist:$INDEX"); }
            [[ -z "$ALBUM" ]] && { ALBUM="Unknown Album"; FAILURE_LOG+=("Album:$INDEX"); }
            [[ -z "$TITLE" ]] && { TITLE=$(basename "$FILE"); FAILURE_LOG+=("Title:$INDEX"); }
        }

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
        MOVED=$((MOVED + 1))
        echo -e "\033[0;32m→ Moved: $FILE → $OUTFILE\033[0m"
    else
        echo "→ Skipped (already exists): $OUTFILE"
    fi

    echo
done

find "$SOURCE" "$DEST" -type d -empty -delete
echo "Moved $MOVED out of $TOTAL files. $NOT_AUDIO files were not audio.\n"
echo "File types: "${FILE_TYPES[@]}\n""
if [ "${#FAILURE_LOG[@]}" -ne 0 ]; then
    printf '%s\n' "${FAILURE_LOG[@]}" | sort | uniq -c
fi
