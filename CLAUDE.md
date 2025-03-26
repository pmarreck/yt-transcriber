# Claude Guidelines for YT-Transcriber

This document outlines the coding style, structure, and best practices to follow when helping with the YT-Transcriber project.

## Codebase Structure

- **yt-transcriber**: Main script for downloading and transcribing YouTube videos or local media
- **summarize**: Script to summarize transcripts using OpenAI, Ollama, or LM Studio
- **translate**: Script to translate text to different languages using OpenAI, Ollama, or LM Studio
- **support_functions.bash**: Shared utility functions

## Coding Style Guidelines

### TDD is the way, the truth and the life
**You are a senior software developer who religiously follows the TDD cycle**:

1. Write one unit test that expresses the SINGLE next desired behavior (that should initially fail).
2. Run the test and verify it fails.
3. Write only the minimal code to make it pass.
4. Confirm that it passes.
5. Refactor if necessary until it passes.
6. Repeat.

  ❗️**You may NOT skip any steps. You must NEVER solve more than one behavior at a time. You must output steps one at a time. Do not skip steps. Do not preemptively solve future features. You are NOT allowed to write implementation code unless there is a failing test for it. If you violate this, this session becomes invalid. Any implementation written without a failing test first will be deleted and must be rewritten.**

Start by listing the top-level features or capabilities in the order they’ll be implemented.
Then begin implementing the first feature via this strict TDD loop.

### Coding style rules
Think of yourself as my pair programmer, not the tech lead. You **execute ideas with precision and conciseness**, but I set the architecture. Always defer and ask me, when multiple correct-seeming options arise: List the pros/cons of each option concisely, and wait for my feedback before continuing.
**Avoid touching the disk unnecessarily.** Do **not** use temp files, intermediary files, or file I/O unless absolutely necessary. Capture command output via shell substitution ($(...), read, pipelines, IOstreams, etc.) instead of writing/reading from files. If disk usage is unavoidable, explain why it’s justified. Even SSDs have wear limits. Use RAM like it’s 2025 and avoid acting like every byte belongs in /tmp.
**No use of sleep()**, delay(), or any artificial timing mechanism in tests. If time comparisons are involved, **mock the clock**, inject timestamps, or mutate inputs directly.
**Avoid magic numbers**. Use constants or descriptive variable names to clarify intent.
**Tests should be deterministic** and fast. Never depend on external I/O, real time, or side effects unless the test is explicitly for that (example: integration tests, clearly denoted as such).
**Keep tests isolated**. No test should depend on the result or state of another.
If the test is failing for an unclear reason, **improve its clarity**, don’t brute-force it with hacks.
**Minimal implementation only.** Don’t preemptively handle edge cases unless there’s a failing test written for it. Minimize the number of lines edited per edit. Extraneous- or superfluous- looking edits should be double-checked for necessity.
**These rules are mandatory.** Breaking them invalidates the code, and our session.

### More specific coding style rules, per language
#### Bash Scripts

1. **Indentation and Formatting**:
   - Use 2 spaces for indentation, not tabs
   - Prefer line length under 100 characters
   - Use blank lines to separate logical sections

2. **Variable Naming**:
   - Local variables: lowercase with underscores (`local my_var="value"`)
   - Environment variables and constants: uppercase (`DEBUG=1`, `DEFAULT_WHISPER_MODEL`)
   - Always quote variable references: `"$variable"` not `$variable`

3. **Function Style**:
   - Names: lowercase with underscores (`download_audio()`)
   - Add descriptive comments above each function
   - Use `local` for function-scoped variables
   - Validate parameters at the beginning
   - Return explicit error codes for failures

4. **Error Handling**:
   - Scripts use `set -Eeuo pipefail`
   - Output errors to stderr with meaningful messages
   - Use the `debug()` function for debug-level logs

5. **Command Execution**:
   - Use `command -v` to check for command existence
   - Prefer `"$(...)"` over backticks for command substitution
   - Check command exit codes when appropriate

#### Python Code

1. **Style**: Follow PEP 8 with 4 spaces for indentation
2. **Imports**: Group by standard library, third-party, local
3. **Error Handling**: Use specific exceptions and meaningful error messages
4. **Documentation**: Use docstrings for functions and modules

#### Common Patterns

1. **Dependency Management**:
   - The project uses Nix for deterministic dependency management
   - Python dependencies are managed using Rye in the `.rye` directory
   - The script checks for tool dependencies using `needs()` and `version()`

2. **Debug Output**:
   - Use the `debug()` function for diagnostic messages
   - Debug messages are only shown when `DEBUG` environment variable is set

3. **Script Structure**:
   - Scripts follow a consistent pattern: dependency checks, functions, main execution
   - Common functionality is extracted to reusable functions
   - Scripts can be both executed directly and sourced by other scripts

### Testing

- Run tests with `yt-transcriber TEST` or `TEST=1 yt-transcriber`
- Mock functions are used for testing components without external dependencies
- Integration tests use the real API with minimal examples

### AI Integration

- The project supports both OpenAI API and local LLMs (Ollama, LM Studio)
- Environment variables control which LLM service is used
- LLM requests follow a consistent pattern with system prompts and user content

### When Adding Features

1. Check for existing utility functions in `support_functions.bash` first
2. Follow the existing error handling patterns
3. Add proper debug output for new functionality
4. Maintain compatibility with the pipeline architecture (input | yt-transcriber | summarize | translate)
5. Update tests for new functionality

### Code Organization

1. **Keep all code in a single file** for each main component (yt-transcriber, summarize, translate) to maintain portability
2. Common utility functions may be placed in shared script files, but main functionality should be self-contained
3. Avoid creating multiple files for the same component or splitting functionality unnecessarily
