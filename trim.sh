#!/bin/bash

# A script to trim a specific number of frames from the start and end of a video
# using ffmpeg for creating seamless loops.
#
# Usage: ./trim.sh [input_file_or_directory] [start_frames] [end_frames]
# Example (file): ./trim.sh my_video.mp4 10 15
# Example (directory): ./trim.sh /path/to/videos 10 15

# --- 1. VALIDATE INPUTS ---

# Check for the correct number of arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_file_or_directory> <frames_to_trim_from_start> <frames_to_trim_from_end>"
    echo "Example (file): $0 source.mp4 10 15"
    echo "Example (directory): $0 /path/to/videos 10 15"
    exit 1
fi

# Assign arguments to variables for clarity
INPUT_PATH="$1"
FRAMES_FROM_START="$2"
FRAMES_FROM_END="$3"

# Check if ffmpeg and ffprobe are installed
if ! command -v ffmpeg &> /dev/null || ! command -v ffprobe &> /dev/null; then
    echo "Error: ffmpeg and ffprobe are not installed or not in your PATH."
    echo "Please install ffmpeg to use this script."
    exit 1
fi

# --- FUNCTION TO TRIM A SINGLE VIDEO ---

trim_video() {
    local INPUT_FILE="$1"
    local FRAMES_FROM_START="$2"
    local FRAMES_FROM_END="$3"

    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file '$INPUT_FILE' not found."
        return 1
    fi

    echo "---"
    echo "Processing video file: $INPUT_FILE"

    # --- 2. GET VIDEO PROPERTIES ---

    echo "Analyzing video file: $INPUT_FILE"

    # Get the video frame rate (r_frame_rate)
    FRAME_RATE_FRAC=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")
    if [ -z "$FRAME_RATE_FRAC" ]; then
        echo "Error: Could not determine frame rate for $INPUT_FILE."
        return 1
    fi
    FRAME_RATE=$(echo "$FRAME_RATE_FRAC" | bc -l)

    # Get the total number of frames
    TOTAL_FRAMES=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of default=nokey=1:noprint_wrappers=1 "$INPUT_FILE")
    if [ -z "$TOTAL_FRAMES" ]; then
        echo "Error: Could not determine total frames for $INPUT_FILE."
        return 1
    fi

    echo "  - Frame Rate: $FRAME_RATE fps"
    echo "  - Total Frames: $TOTAL_FRAMES"

    # --- 3. CALCULATE TRIM PARAMETERS ---

    START_FRAME_INDEX=$FRAMES_FROM_START
    FRAMES_TO_KEEP=$((TOTAL_FRAMES - FRAMES_FROM_START - FRAMES_FROM_END))
    LAST_FRAME_INDEX=$((TOTAL_FRAMES - FRAMES_FROM_END - 1))

    if (( FRAMES_TO_KEEP <= 0 )); then
        echo "Error: The number of frames to trim is greater than or equal to the total frames in the video."
        return 1
    fi

    echo "Calculating trim..."
    echo "  - Keeping frames from index $START_FRAME_INDEX to $LAST_FRAME_INDEX"
    echo "  - Total frames in output: $FRAMES_TO_KEEP"

    # --- 4. CONSTRUCT FILENAME & FFMPEG COMMAND ---

    EXTENSION="${INPUT_FILE##*.}"
    INPUT_BASENAME=$(basename "$INPUT_FILE" ".$EXTENSION")
    OUTPUT_FILE="${INPUT_BASENAME}_trim_s_${FRAMES_FROM_START}_e_${FRAMES_FROM_END}.${EXTENSION}"

    FFMPEG_CMD=(
      ffmpeg
      -i "$INPUT_FILE"
      -vf "select='between(n,${START_FRAME_INDEX},${LAST_FRAME_INDEX})',setpts=PTS-STARTPTS"
      -an
      -y
      "$OUTPUT_FILE"
    )

    # --- 5. EXECUTE ---

    echo "Trimming video... This may take a moment."
    echo "Executing command:"
    printf "%s " "${FFMPEG_CMD[@]}"
    echo

    "${FFMPEG_CMD[@]}"

    if [ $? -eq 0 ]; then
        echo "✅ Success! Video trimmed successfully."
        echo "Output saved to: $OUTPUT_FILE"
    else
        echo "❌ Error: ffmpeg command failed for $INPUT_FILE."
        return 1
    fi
}

# --- MAIN LOGIC ---

if [ -d "$INPUT_PATH" ]; then
    echo "Input is a directory. Processing all .mp4 files..."
    for file in "$INPUT_PATH"/*.mp4; do
        if [ -f "$file" ]; then
            trim_video "$file" "$FRAMES_FROM_START" "$FRAMES_FROM_END"
        fi
    done
    echo "---"
    echo "All .mp4 files in the directory have been processed."
elif [ -f "$INPUT_PATH" ]; then
    trim_video "$INPUT_PATH" "$FRAMES_FROM_START" "$FRAMES_FROM_END"
else
    echo "Error: Input '$INPUT_PATH' is not a valid file or directory."
    exit 1
fi

exit 0
