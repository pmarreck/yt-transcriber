# TODO

1. ✅ (2025-11-14) Add a `--clear-video-cache [<youtube-id>]` option that deletes cached audio/transcripts (all IDs when no argument is provided, or just the specified ID when given).

Future:

2. Expand download support beyond YouTube (other video/web sources). 
3. Add caching for the `summarize` and `translate` commands
4. Add a possible web service option, as well as options for storing the cache somewhere else like a different directory, S3 or minio bucket, or a sqlite or postgres db (all of which will also require a way to store last-accessed time and a periodic job to clear old cache entries that haven't been accessed beyond a certain amount of configurable time, or when the total cache size is above a certain configurable size limit)
