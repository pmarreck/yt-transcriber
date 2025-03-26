# yt-transcriber

TUI app- Give it a YouTube URL (or a path to a video or audio file) and you get a transcription with possible speaker identification (WIP) and optional summary or translation, all thanks to open-source AI tooling and my lack of enough free time to watch content-sparse YouTube videos

## features

- [x] transcribe YouTube videos by URL
- [x] output metadata about the video
- [ ] speaker identification (probably using an LLM in conjunction with a speaker diarization library)
- [x] summarization via `summarize` (requires `OPENAI_API_KEY` to be set)
- [x] translation via `translate <language_name>` (requires `OPENAI_API_KEY` to be set)
- [x] can use almost any audio or video format that `ffmpeg` can handle as input, not just YouTube URLs
- [x] Test suite (run it with `yt-transcriber TEST` or `TEST=1 yt-transcriber`)
- [ ] support for other video platforms
- [ ] convert all this to a web service or web app

Speaker identification ("diarization"), summarization and translation will probably require an API key for Claude or OpenAI and/or one from Huggingface.

## installation

NEW: If you have Nix installed or are running on NixOS, just symlink `yt-transcriber`, `summarize`
and `translate` to any directory (usually `~/bin` or `XDG_BIN_HOME` which is usually `~/.local/bin`)
in your `PATH` and you're good to go (the last two require OPENAI_API_KEY to be
defined in your environment). The shell script will automatically procure all dependencies
deterministically and locally and cache them.

If you do not have Nix installed, I recommend using the Determinate Nix Installer from here:
https://github.com/DeterminateSystems/nix-installer

If you refuse to use Nix, you can try to install the following dependencies manually, but I make no guarantees:

```bash
python312
ffmpeg
glow
phantomjs  # Optional, but recommended for better YouTube extraction
```

(`glow` is optional; if using the `--markdown|-md` argument with `summarize`, this makes things prettier in the terminal if you pipe to it)
(`phantomjs` is optional but recommended for better YouTube video extraction - it helps avoid "nsig extraction failed" warnings)
The Python dependencies will be installed via pip into a venv cached in `$XDG_CACHE_HOME/yt-transcriber/.venv`
and XDG_CACHE_HOME defaults to `~/.cache` if not set.
The Whisper model will be downloaded to `$XDG_CACHE_HOME/yt-transcriber/.whisper`.

the `flake.nix` file manages all deps, so just `nix develop` when in there.
`./test_flake.sh` tests whether everything's set up correctly.
`./yt_transcriber TEST` tests the app itself.
No app keys needed, Whisper runs locally.
Setup was only tested on Mac with a Nix install thus far. Will add tests for it working without Nix next.

## example usage

`./yt-transcriber` by itself will list options and usage (such as `-m modelsize`).

By default the app uses the `small` (second smallest) model; I recommend using at least `small` for better transcription results without costing too much extra processing time. The options are: `base`, `small`, `medium`, `large`, `large-v2`

Transcript will be sent to stdout, so you can redirect it to a file or pipe it to another program such as the provided `./summarize[--markdown]` or `./translate [language]` scripts (see below).

If you set the `DEBUG` env var (to anything), you'll get additional logging/debug info to stderr.

```bash
# (when in the project directory)
./yt-transcriber -m medium "https://www.youtube.com/watch?v=<youtube_id>" > ~/Documents/transcript.txt
```

```bash
# (when in the project directory)
./yt-transcriber -m small "/path/to/video/or/audio/file.mp4" | ./summarize | ./translate Süddeutsch > ~/Documents/bavarian_german_summary.txt
```

```bash
# (when yt-transcriber is on PATH)
yt-transcriber "https://www.youtube.com/watch?v=<youtube_id>" | summarize --markdown | glow
```

For a full debug run try this:

```bash
# (when in the project directory)
DEBUG=1 ./yt-transcriber -m small "https://www.youtube.com/watch?v=<youtube_id>" | tee last_transcript.txt | ./summarize
```
