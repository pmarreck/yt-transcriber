# yt-transcriber

TUI app- Give it a YouTube URL (or a path to a video or audio file) and you get a transcription with possible speaker identification (WIP) and optional summary or translation, all thanks to open-source AI tooling and my lack of enough free time to watch content-sparse YouTube videos

## features

- [x] transcribe YouTube videos by URL
- [x] output metadata about the video
- [ ] speaker identification (probably using an LLM in conjunction with a speaker diarization library)
- [x] summarization via `summarize` (requires `OPENAI_API_KEY` to be set)
- [x] translation via `translate <language_name>` (requires `OPENAI_API_KEY` to be set)
- [x] can use almost any audio or video format that `ffmpeg` can handle as input, not just YouTube URLs
- [ ] support for other video platforms
- [ ] convert all this to a web service or web app

Speaker identification ("diarization"), summarization and translation will probably require an API key for Claude or OpenAI and/or one from Huggingface.

## installation

the `flake.nix` file manages all deps, so just `nix develop` when in there.
`./test_flake.sh` tests whether everything's set up correctly.
`./test_yt_transcriber.sh` tests the app itself.
No app keys needed, Whisper runs locally.
Setup was only tested on Mac thus far.

## example usage

`./yt-transcriber` by itself will list options and usage (such as `-m modelsize`).

By default the app uses the `base` (smallest) model; I recommend going to at least `small` for better transcription results without costing too much extra processing time.

Transcript will be sent to stdout, so you can redirect it to a file or pipe it to another program such as the provided `./summarize` or `./translate <language>` scripts (see below).

If you set the `DEBUG` env var (to anything), you'll get additional logging/debug info to stderr.

```bash
# (when in the project directory)
./yt-transcriber -m small "https://www.youtube.com/watch?v=<youtube_id>" > ~/Documents/transcript.txt
```

```bash
# (when in the project directory)
./yt-transcriber -m small "/path/to/video/or/audio/file.mp4" | ./summarize | ./translate Süddeutsch > ~/Documents/bavarian_german_summary.txt
```
