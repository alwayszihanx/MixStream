# Changelog

All notable changes to MixStream are documented here. The format loosely follows [Keep a Changelog](https://keepachangelog.com/).

---

## [3.7.0] - Latest

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

