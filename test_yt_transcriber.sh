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
  debug "Mock download called with URL: $url, output dir: $output_dir"
  echo "Mock download completed (testing mode)"
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

  # Clear any existing files
  rm -f "$cache_file"

  # Run the script
  "${SCRIPT_DIR}/yt-transcriber" "$test_url" >/dev/null 2>&1

  # Verify the file exists and has content
  assert_file_exists "$cache_file"

  # Verify it's not empty
  if [ ! -s "$cache_file" ]; then
    echo "❌ Test failed: Downloaded file is empty"
    exit 1
  fi

  # Verify it's actually an audio file
  if ! file "$cache_file" | grep -qE "Audio|audio"; then
    echo "❌ Test failed: File is not an audio file"
    echo "File type: $(file "$cache_file")"
    exit 1
  fi

  echo "✅ Test passed: Audio file downloaded successfully"
}

# Test 6: Script uses cached audio file if available
test_audio_cache() {
  local test_url="https://www.youtube.com/watch?v=jNQXAC9IVRw"
  local youtube_id="jNQXAC9IVRw"
  local cache_file="/tmp/yt-transcriber/${youtube_id}.mp3"

  # Ensure we start with no cache
  rm -f "$cache_file"

  # Create a fake cached file
  mkdir -p "/tmp/yt-transcriber"
  dd if=/dev/zero of="$cache_file" bs=1024 count=1 2>/dev/null
  local original_size
  original_size=$(wc -c < "$cache_file")

  # Run the script - it should use the existing file
  "${SCRIPT_DIR}/yt-transcriber" "$test_url" >/dev/null 2>&1

  # Verify the file wasn't redownloaded (size shouldn't change)
  local new_size
  new_size=$(wc -c < "$cache_file")

  if [ "$original_size" -ne "$new_size" ]; then
    echo "❌ Test failed: Cache file was modified (redownloaded)"
    echo "Original size: $original_size"
    echo "New size: $new_size"
    exit 1
  fi

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

# Run tests
debug "Starting test suite"
echo -e "${YELLOW}Running YT Transcriber tests...${NC}"
run_test "Script exists and executable" test_script_exists
run_test "Usage message" test_usage
run_test "URL validation" test_url_validation
run_test "Working directory creation" test_working_dir
run_test "Audio caching" test_audio_cache
run_test "Audio download" test_audio_download
run_test "Audio transcription" test_transcription
echo -e "${GREEN}All tests passed!${NC}"
debug "Test suite completed"
