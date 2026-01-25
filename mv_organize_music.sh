#!/usr/bin/env bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

if ! command -v ffprobe &> /dev/null; then
    echo "ffprobe is required, but it was not found."
    exit 1
fi

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
    BASENAME=$(basename "$FILE")
    NAME="${BASENAME%.*}"

    SAFE_ARTIST=""
    SAFE_ALBUM=""
    SAFE_TITLE=""

    PARENT_DIR=$(basename "$(dirname "$FILE")")
    GRANDPARENT_DIR=$(basename "$(dirname "$(dirname "$FILE")")")
    ARTIST=${ARTIST:-$GRANDPARENT_DIR}
    ALBUM=${ALBUM:-$PARENT_DIR}

    # 3. Final Fallback: Hardcoded defaults if guessing also fails
    ARTIST=${ARTIST:-"Unknown Artist"}
    ALBUM=${ALBUM:-"Unknown Album"}
    TITLE=${TITLE:-$NAME}
    
    INDEX=$((i + 1))
    PERCENT=$((INDEX * 100 / TOTAL))
    
    echo "[${INDEX}/${TOTAL}] (${PERCENT}%) Processing: $BASENAME"
    
    FILETYPE=$(file --brief --mime-type "$FILE" 2>/dev/null || true)
    if [ -z "$FILETYPE" ]; then
        case "$FILE" in
            *.flac) FILETYPE="audio";;
            *.mp3) FILETYPE="audio";;
            *.m4a) FILETYPE="audio";;
            *.wav) FILETYPE="audio";;
            *) FILETYPE="unknown";;
        esac
    fi

    FILE_TYPES+=("$FILETYPE")
    
    if [[ "$FILETYPE" != audio/* ]]; then
        NOT_AUDIO=$((NOT_AUDIO + 1))
    else
        ARTIST=$(ffprobe -v quiet -show_entries format_tags=artist:stream_tags=artist \
            -of default=noprint_wrappers=1:nokey=1 "$FILE" | head -n1)
        ALBUM=$(ffprobe -v quiet -show_entries format_tags=album:stream_tags=album \
            -of default=noprint_wrappers=1:nokey=1 "$FILE" | head -n1)
        TITLE=$(ffprobe -v quiet -show_entries format_tags=title:stream_tags=title \
            -of default=noprint_wrappers=1:nokey=1 "$FILE" | head -n1)

        if [[ -z "$ARTIST" ]]; then
            FAILURE_LOG+=("Artist:$INDEX")
        fi

        if [[ -z "$ALBUM" ]]; then
            FAILURE_LOG+=("Album:$INDEX")
        fi

        if [[ -z "$TITLE" ]]; then
            FAILURE_LOG+=("Title:$INDEX")
        fi

    fi
    SAFE_ARTIST=$(sanitize "$ARTIST")
    SAFE_ALBUM=$(sanitize "$ALBUM")
    SAFE_TITLE=$(sanitize "$TITLE")

    DEST_DIR="${DEST%/}/$SAFE_ARTIST/$SAFE_ALBUM"
    mkdir -p "$DEST_DIR"

    EXT=""
    if [[ "$BASENAME" == *.* ]]; then
        EXT="${BASENAME##*.}"
    fi

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
echo -e "Moved $MOVED out of $TOTAL files. $NOT_AUDIO files were not audio.\n"
echo -e "File types: $(printf "%s\n" "${FILE_TYPES[@]}" | sort -u)\n"
if [ "${#FAILURE_LOG[@]}" -ne 0 ]; then
    printf '%s\n' "${FAILURE_LOG[@]}" | sort | uniq -c
fi
