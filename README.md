
# Music Organization Script

This script organizes your music collection by moving audio files based on their metadata (Artist, Album, Title). It sanitizes file names for file system compatibility and can handle long file names and special characters.

## Prerequisites
- **ffprobe** (part of FFmpeg) must be installed.
- **Bash**: Works on Unix-based systems (Linux, macOS).

### Installation:
1. Clone or download the script.
2. Make it executable: 
    ```bash
    chmod +x mv_organize_music.sh
    ```
3. Run the script with source and destination directories:
    ```bash
    ./mv_organize_music.sh /path/to/source /path/to/destination
    ```

## Usage:
```bash
./mv_organize_music.sh /path/to/source /path/to/destination
```

### Arguments:
- **Source Directory**: Defaults to the current directory if not specified.
- **Destination Directory**: Defaults to `./organized`.

### Example:
```bash
./mv_organize_music.sh ~/Music ~/Music/Organized
```

## Features:
- **Sanitizes File Names**: Replaces invalid characters (`:`, `/`, etc.) with underscores.
- **Metadata-based Organization**: Organizes files into Artist/Album/Title directories.
- **Skips Existing Files**: Files already in the destination are not moved.

## Known Issues:
- Files with long names may fail to move due to system restrictions.
- Some special characters may still cause issues despite sanitization.

## License:
MIT License. See [LICENSE](LICENSE) for more details.
