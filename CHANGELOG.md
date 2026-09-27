---

## [3.7.1] - Latest

### 📥 Batch Episode Download
- **Multi-select episodes** — select episodes straight from the list and download a whole season in one action. Works for both extension-backed items (`EpisodeCard`) and TMDB/Nuvio shows (`MovieSeasonsList`).
- **Select all (N) / This page** — no more paging through a 300-episode show 20 episodes at a time.
- **Parallel resolution** — episodes resolve through a bounded 3-wide worker pool instead of one serial scraper round-trip each, so a 20-episode batch finishes several times faster.
- **Skip already-downloaded** — re-running a batch no longer re-downloads episodes you already have.
- **Robust selection keys** — selection is keyed by `S<season>-E<episode>` rather than the episode URL, which is empty for TMDB entries and previously made every episode collide on one key.
- **Stable tracking IDs** — stops episodes in a batch clobbering each other's download progress.

### 🎬 HLS Download & MKV Conversion
- **Real MKV output** — every download is remuxed from MP4 into a genuine `.mkv` by a new pure-Dart remuxer (no FFmpeg dependency). Samples are copied packet-for-packet, so there is no quality loss and A/V sync from the MP4 edit tables is preserved.
- **HLS support** — `.m3u8` sources are now downloadable. Segments are fetched concurrently, **AES-128 encrypted** playlists are decrypted, MPEG-TS is demuxed to H.264/AAC, and the result is written as MKV.
- **Live playlists rejected clearly** — an on-demand-only error instead of hanging or saving a broken file.
- **Conversion progress** — the Downloads row shows a live percentage while converting.
- **Conversion failures surfaced** — the original file is always kept and the row reads *"Kept as MP4 (MKV conversion failed)"* instead of silently reporting success.
- **Gentler on the device** — conversions are queued (max 2 at a time), so a batch finishing together no longer spawns a burst of isolates.
- **Faster path lookups** — downloaded-file paths are cached instead of re-probing the filesystem on every rebuild.

### 🏠 Home Screen
- **Regional shelves** — 14 new movie & series rows, newest-first so new releases surface automatically: Latest, Hollywood, Bollywood, South Indian, Indonesian, Korean, Turkish, British, French, German, Russian, Chinese, Japanese and Arabic.
- **Real industry filtering** — shelves use TMDB origin-country filters, splitting Indian cinema correctly into Bollywood (Hindi) and South Indian (Telugu/Tamil/Malayalam/Kannada).
- **Genuinely "latest"** — the Latest shelf uses a rolling 90-day release window instead of sorting all-time by date, which had been surfacing unrated placeholder entries.
- **Per-shelf vote floors** — filter out empty entries so the rows stay worth scrolling.
- **Progressive loading** — shelves appear as each resolves instead of blocking the whole page.
- **Single Continue Watching** — removed the duplicate section that sat above the hero carousel.

### 📺 Details Screen
- **"3 of 12 downloaded" badge** — per-season download progress, read from the download folder in a single pass.
- **Converted files preferred** — an MKV is returned in place of the MP4 it replaced.

### 🎬 Nuvio Scraper Layer
- **Nuvio-aware batch download** — Nuvio is not a `MixStreamProvider`, so the batch path now resolves sources through the Nuvio scrapers using the TMDB id plus season/episode.
- **Scraper sessions now survive to download** — cookies collected while scraping are exported and attached to the stream, fixing downloads that failed with 403 while playback worked.
- **Downloadable links are no longer hidden** — the download-mode filter and the per-row download button now agree, so torrent rows (with debrid) and protocol-relative `//host/file.mp4` links appear correctly.
- **Extension-less links accepted** — scraper links without a file extension are probed and accepted on their content type.
- **Fewer repeat scraper runs** — scraper code is cached in memory, so a batch reads each script once instead of once per episode.
- **Reliability ranking** — sources now sort by how often each scraper has actually delivered, with a small-sample prior so one lucky hit doesn't win.

### 🛠 Under the Hood
- **Connectivity fix** — `connectivity_plus` returns a list of results now; the offline card was comparing against a single value.
- **`untranslated-messages-file`** is configured in `l10n.yaml` so CI's translation-coverage gate has the report it expects.

### 🐛 Fixed
- Matroska `TrackNumber` was written as a variable-length integer instead of a plain integer, producing *"Invalid track number"* and no duration.
- Converted samples shared one reusable buffer, so every block in a file received the same bytes.
- Negative timestamps (from AAC priming edit lists) were never shifted, producing a bogus cluster timestamp of 235 ms and non-monotonic audio.
- MP4 `Duration` is a float, not an integer, so playback duration was reported as 0.

---

## [3.7.0]
### 📺 Enhanced Details Screen
- **Poster zoom overlay** — double-tap any poster to zoom with a floating action menu (Play, Bookmark, Download) for quick access without leaving the screen.
- **Scroll-driven hero stretch** — the hero poster now stretches and compresses as you scroll, giving a cinematic parallax depth effect on desktop/TV.
- **Error & empty states** — replaced raw error text with friendly `_DetailsErrorView` (with retry button) and `_DetailsEmptyView` so the screen is never blank when data fails to load.
- **Graceful provider fallback** — when no registered extension matches an item, the original payload renders immediately and metadata resolution runs in the background instead of crashing.

### 🔄 Watched Progress Tracking
- **WatchProgressRepository** — per-episode progress tracking stored persistently, with `markWatched`, `markUnwatched`, and `savePosition` methods.
- **EpisodeWatchedActionSheet** — bottom sheet to mark individual episodes watched/unwatched with reset progress option.
- **SeasonWatchedActionSheet** — bottom sheet to mark all episodes in a season watched/unwatched, with progress count shown.
- **EpisodeWatchRepository** — extended to support explicit watched overrides with automatic detection based on playback position (90% threshold).

### 📡 Connectivity & Offline
- **NetworkOfflineCard** — persistent connectivity indicator banner shown at the top of the details screen on both mobile and desktop. Auto-updates in real-time via `Connectivity().onConnectivityChanged`.

### 🏠 Enhanced Home Screen
- **Continue Watching Hero Slot** — hero-sized continue-watching carousel at the top of the home screen so you can pick up where you left off instantly without scrolling.
- **ContinueWatchingHeroViewportReserve** — dedicated layout spacer ensuring smooth scrolling without content overlap.

### 🎬 Nuvio Integration
- Improved **Nuvio plugin** metadata handling and plugin sources sheet.
- **Debrid integration** wired into Nuvio sources for premium link resolution.

### 🛠 Under the Hood
- Disabled Impeller rendering backend on Android (fell back to Skia) to fix device-specific rendering regressions.
- Splash pacing rebalanced for a calmer, more cinematic feel.

---

### 🎬 Cinematic 7-Stage Splash
- Brand-new intro sequence: the screen opens on pure black, an **ambient green glow** blooms from the center, and **real genre posters** (Horror, Thriller, Action, Sci-Fi, Anime, Drama, Comedy, Documentary) fade and scale in from every direction with subtle rotation.
- The posters drift toward the center, collapse into the **MixStream** logo (`mixstream.png`), which then cross-fades into the full **wordmark**, followed by a light sweep across the logo and a hold on the "Unlimited Movies & Shows" tagline.
- The splash now fades to black at the end so it hands off **seamlessly** into the dark app — no white flash, no jank.

### 🌑 Dark-Only Mode
- The app is now **dark mode only**. The system/light theme options have been removed; `ThemeMode.dark` is forced app-wide so the experience is consistent everywhere.
- The native Android splash and the Flutter splash both use the same deep-dark surface for a continuous, unified look.

### 🟢 Wordmark Branding
- The **home screen AppBar** now displays the **MixStream wordmark logo** (PNG) instead of the plain "MixStream" text.
- The branding is consistent across the splash (logo formation) and the home screen.

### 🛠 Under the Hood
- Disabled the Impeller rendering backend on Android (fell back to Skia) to fix device-specific rendering regressions (opacity-on-image crashes, blur hangs, full-screen opacity washout).
- Splash pacing rebalanced for a calmer, more cinematic feel (poster emergence and logo hold given more breathing room).

---

