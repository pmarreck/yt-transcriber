#!/usr/bin/env bash

debug() {
  if [[ $# -gt 0 ]]; then
    # With args, just print to stderr if DEBUG is set
    [[ -n "$DEBUG" ]] && printf "\nDEBUG: %s\n" "$*" >&2
  else
    # If no args but stdin has content
    if ! [ -t 0 ]; then
      if [[ -n "$DEBUG" ]]; then
        # Debug mode: tee to stderr (with prefix) while passing clean data to stdout
        printf "\n" >&2
        tee >(sed 's/^/DEBUG: /' >&2)
        printf "\n" >&2
      else
        # No debug: just pass through
        cat
      fi
    fi
  fi
}

validate_ollama_model() {
  local model="$1"
  debug "Checking Ollama model: $model"
  if ! ollama list | tail -n +2 | awk '{print $1}' | grep -q "^${model}$"; then
    echo "Error: Model '${model}' not found in Ollama. Available models:" >&2
    ollama list | tail -n +2 | awk '{print "- "$1}' >&2
    return 1
  fi
  return 0
}

validate_lm_studio_response() {
  local response="$1"
  local model="$2"

  debug "Raw response from LM Studio:"
  debug "$(echo "$response" | jq .)"

  if [[ -z "$response" ]] || [[ "$response" == "null" ]]; then
    echo "Error: No response from LM Studio. Possible issues:" >&2
    echo "- Model '${model}' is not loaded" >&2
    echo "- LM Studio server is not running on port 1234" >&2
    echo "- Server error occurred" >&2
    echo "Please load the model in LM Studio and try again." >&2
    return 1
  fi

  if echo "$response" | jq -e '.error' >/dev/null; then
    echo "Error from LM Studio:" >&2
    echo "$response" | jq -r '.error.message' >&2
    return 1
  fi

  local loaded_model=$(echo "$response" | jq -r '.model')
  debug "Using loaded model in LM Studio: $loaded_model"

  # Only warn about model mismatch if a specific model was requested
  if [[ -n "$model" && "$loaded_model" != "$model" ]]; then
    echo -e "\033[38;5;208mWarning: Requested model '${model}' differs from currently loaded model in LM Studio: '${loaded_model}'\033[0m" >&2
    echo -e "\033[38;5;208mLM Studio will use the currently loaded model regardless of what was specified.\033[0m" >&2
  fi

  return 0
}
