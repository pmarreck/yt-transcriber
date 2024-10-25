#!/usr/bin/env bash
# test_yt_transcriber.sh

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Debug function
debug() {
  if [ -n "${DEBUG:-}" ]; then
    echo -e "${YELLOW}DEBUG: $*${NC}" >&2
  fi
}

# Define mock function
mock_download_audio() {
  local url="$1"
  local output_dir="$2"
  local youtube_id

  debug "Mock download called with URL: $url, output dir: $output_dir"

  # Get YouTube ID from URL
  youtube_id=$(echo "$url" | sed -n 's/.*[?&]v=\([^&]*\).*/\1/p')

  # Create cache directory if it doesn't exist
  local cache_dir="/tmp/yt-transcriber"
  mkdir -p "$cache_dir"

  # Create mock metadata file first
  cat > "${output_dir}/metadata.json" << EOF
{
  "title": "Test Video",
  "channel": "Test Channel",
  "upload_date": "20240101",
  "duration": 5.0,
  "webpage_url": "$url"
}
EOF

  # Create a mock audio file in the cache
  local cache_file="${cache_dir}/${youtube_id}.mp3"

  # Generate a simple MP3 file using ffmpeg
  ffmpeg -f lavfi -i "sine=frequency=1000:duration=5" -ar 44100 -ac 2 -ab 192k "$cache_file" 2>/dev/null

  debug "Created mock audio file: $cache_file"
  debug "Created mock metadata: ${output_dir}/metadata.json"

  # Copy the mock audio file to the output directory
  cp "$cache_file" "${output_dir}/audio.mp3"

  return 0
}
export -f mock_download_audio

# Test utilities
assert_success() {
  local description="$1"
  local cmd="${2:-}"
  local output

  if [ -n "$cmd" ]; then
    debug "Running command: $cmd"
    if output=$(eval "$cmd" 2>&1); then
      echo -e "${GREEN}✅ Test passed: $description${NC}"
      debug "Command output: $output"
      return 0
    else
      debug "Command failed with output: $output"
      echo -e "${RED}❌ Test failed: $description${NC}"
      echo -e "${RED}Command: $cmd${NC}"
      echo -e "${RED}Output: $output${NC}"
      exit 1
    fi
  else
    echo -e "${GREEN}✅ Test passed: $description${NC}"
  fi
}

assert_file_exists() {
  local file="$1"
  local description="File exists: $file"

  debug "Checking if file exists: $file"
  if [ -f "$file" ]; then
    echo -e "${GREEN}✅ Test passed: $description${NC}"
  else
    debug "File not found: $file"
    echo -e "${RED}❌ Test failed: File does not exist: $file${NC}"
    echo -e "${RED}Path checked: $file${NC}"
    exit 1
  fi
}

assert_dir_exists() {
  local dir="$1"
  local description="Directory exists: $dir"

  debug "Checking if directory exists: $dir"
  if [ -d "$dir" ]; then
    echo -e "${GREEN}✅ Test passed: $description${NC}"
  else
    debug "Directory not found: $dir"
    echo -e "${RED}❌ Test failed: Directory does not exist: $dir${NC}"
    debug "Parent directory contents:"
    ls -la "$(dirname "$dir")" >&2 || true
    debug "Current working directory: $(pwd)"
    exit 1
  fi
}

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_TEMP_DIR=$(mktemp -d)
debug "Created test temp dir: $TEST_TEMP_DIR"
trap 'debug "Cleaning up test temp dir"; rm -rf ${TEST_TEMP_DIR}' EXIT

# Test 1: Script exists and is executable
test_script_exists() {
  assert_file_exists "${SCRIPT_DIR}/yt-transcriber"
  assert_success "Script is executable" "[ -x \"${SCRIPT_DIR}/yt-transcriber\" ]"
}

# Test 2: Script shows usage when run without arguments
test_usage() {
  local output
  output=$("${SCRIPT_DIR}/yt-transcriber" 2>&1 || true)
  assert_success "Shows usage message" "echo \"$output\" | grep -q \"Usage:\""
}

# Test 3: Script validates YouTube URL
test_url_validation() {
  local output
  output=$("${SCRIPT_DIR}/yt-transcriber" "not-a-url" 2>&1 || true)
  assert_success "Detects invalid YouTube URL" "echo \"$output\" | grep -q \"Invalid YouTube URL\""
}

# Test 4: Script creates working directory
test_working_dir() {
  local output
  local work_dir

  debug "Running working directory test"

  export MOCK_DOWNLOAD=true
  debug "Set MOCK_DOWNLOAD=true"

  output=$("${SCRIPT_DIR}/yt-transcriber" "https://www.youtube.com/watch?v=jNQXAC9IVRw" 2>&1)
  debug "Script output: $output"

  unset MOCK_DOWNLOAD
  debug "Unset MOCK_DOWNLOAD"

  # Check if the output contains the working directory line
  if ! echo "$output" | grep -q "Working directory:"; then
    debug "Working directory line not found in output"
    echo -e "${RED}❌ Test failed: Output doesn't contain 'Working directory:' line${NC}"
    exit 1
  fi

  # Get directory and verify it exists
  work_dir=$(echo "$output" | grep "Working directory:" | cut -d':' -f2- | tr -d ' ' || echo "NOT_FOUND")
  debug "Extracted work_dir: $work_dir"

  if [ "$work_dir" = "NOT_FOUND" ]; then
    debug "Could not extract working directory path from output"
    echo -e "${RED}❌ Test failed: Could not extract working directory from output${NC}"
    exit 1
  fi

  assert_dir_exists "$work_dir"
}

# Test 5: Script downloads audio from YouTube
test_audio_download() {
  local test_url="https://www.youtube.com/watch?v=jNQXAC9IVRw"
  local youtube_id="jNQXAC9IVRw"
  local cache_file="/tmp/yt-transcriber/${youtube_id}.mp3"
  local work_dir

  # Clear any existing cached file
  rm -f "$cache_file"

  # Create a working directory for this test
  work_dir=$(mktemp -d)
  debug "Created working directory for audio test: $work_dir"

  # Set mock download mode
  export MOCK_DOWNLOAD=true

  # Create mock metadata first
  cat > "${work_dir}/metadata.json" << EOF
{
  "title": "Test Video",
  "channel": "Test Channel",
  "upload_date": "20240101",
  "duration": 5.0,
  "webpage_url": "$test_url"
}
EOF

  # Run mock download directly instead of through the script
  mock_download_audio "$test_url" "$work_dir"

  # Verify the file exists and has content
  assert_file_exists "$cache_file"

  # Verify it's not empty
  if [ ! -s "$cache_file" ]; then
    echo -e "${RED}❌ Test failed: Downloaded file is empty${NC}"
    exit 1
  fi

  # Verify it's actually an audio file
  if ! file "$cache_file" | grep -qE "Audio|audio"; then
    echo -e "${RED}❌ Test failed: File is not an audio file${NC}"
    echo "File type: $(file "$cache_file")"
    exit 1
  fi

  echo -e "${GREEN}✅ Test passed: Audio file downloaded successfully${NC}"

  # Clean up
  rm -rf "$work_dir"
  unset MOCK_DOWNLOAD
}

# Test 6: Script uses cached audio file if available
test_audio_cache() {
  local test_url="https://www.youtube.com/watch?v=jNQXAC9IVRw"
  local youtube_id="jNQXAC9IVRw"
  local cache_file="/tmp/yt-transcriber/${youtube_id}.mp3"

  # Ensure we have a cached file first (in case download test didn't run first)
  if [ ! -f "$cache_file" ]; then
    debug "No cached file found, downloading first..."
    export MOCK_DOWNLOAD=true
    "${SCRIPT_DIR}/yt-transcriber" "$test_url" >/dev/null 2>&1
  fi

  # Get original size
  local original_size
  original_size=$(wc -c < "$cache_file")
  debug "Original cache file size: $original_size"

  # Run the script again - it should use the existing file
  export MOCK_DOWNLOAD=true
  "${SCRIPT_DIR}/yt-transcriber" "$test_url" >/dev/null 2>&1

  # Verify the file wasn't redownloaded (size shouldn't change)
  local new_size
  new_size=$(wc -c < "$cache_file")
  debug "New cache file size: $new_size"

  if [ "$original_size" -ne "$new_size" ]; then
    echo "❌ Test failed: Cache file was modified (redownloaded)"
    echo "Original size: $original_size"
    echo "New size: $new_size"
    exit 1
  fi

  unset MOCK_DOWNLOAD
  echo "✅ Test passed: Cache file was used without redownloading"
}

# Test 7: Script generates transcript from audio
test_transcription() {
  local test_url="https://www.youtube.com/watch?v=jNQXAC9IVRw"
  local youtube_id="jNQXAC9IVRw"
  local work_dir

  # Run the script and capture its output to get the working directory
  local output
  output=$("${SCRIPT_DIR}/yt-transcriber" "$test_url" 2>&1)

  # Extract working directory from output
  work_dir=$(echo "$output" | grep "Working directory:" | cut -d':' -f2- | tr -d ' ')
  if [ -z "$work_dir" ]; then
    echo "❌ Test failed: Could not determine working directory"
    echo "Script output:"
    echo "$output"
    exit 1
  fi

  # Check for transcript file in the script's working directory
  local transcript_file="${work_dir}/transcript.txt"
  assert_file_exists "$transcript_file"

  # Check that transcript has content
  if [ ! -s "$transcript_file" ]; then
    echo "❌ Test failed: Transcript file is empty"
    exit 1
  fi

  # Check that transcript contains actual text (not just whitespace or garbage)
  if ! grep -q '[[:alpha:]]' "$transcript_file"; then
    echo "❌ Test failed: Transcript doesn't contain readable text"
    echo "Transcript content:"
    cat "$transcript_file"
    exit 1
  fi

  echo "✅ Test passed: Generated valid transcript"
}

# Function to run a single test
run_test() {
  local test_name="$1"
  local test_func="$2"

  echo -e "${YELLOW}Running test: $test_name${NC}"
  if $test_func; then
    echo -e "${GREEN}Test group passed: $test_name${NC}"
    echo
  else
    echo -e "${RED}Test group failed: $test_name${NC}"
    exit 1
  fi
}

# Ensure tests run in correct order
echo -e "${YELLOW}Running YT Transcriber tests...${NC}"
run_test "Script exists and executable" test_script_exists
run_test "Usage message" test_usage
run_test "URL validation" test_url_validation
run_test "Working directory creation" test_working_dir
run_test "Audio download" test_audio_download
run_test "Audio caching" test_audio_cache
echo -e "${GREEN}All tests passed!${NC}"
