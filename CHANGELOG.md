# Changelogs

All notable changes to MixStream are documented here. The format loosely follows [Keep a Changelog](https://keepachangelog.com/).

---

## [3.6.6] - Latest

### ✨ New Features
- **Custom Loading Indicators** – Replaced the stock Material spinner everywhere with a hand-crafted **dot-pulse loader**: glowing dots travel around a ring in a brightening wave (accent gradient cycle), with a compact `.small` variant (16–20px) for thumbnails, episode cards, and the switch-account screen.
- **Hero Bookmark Toggle** – The hero "Save" placeholder was replaced with a real per-profile **Bookmark/Bookmarked** button wired to the library. Saved items render a filled, accent-colored bookmark and appear in Library → Bookmarks.

### 🖥️ Desktop & Window Experience
- **Slimmer Title Bar** – Reduced custom title bar height (48→36px), compact 28px window buttons and 14px icons for close, fullscreen/always-on-top, and pin controls.

### 🎬 Hero Carousel Polish
- **Gradient Titles** – Hero titles now use a Disney-style gradient (white → primary → tertiary) via a `ShaderMask`.
- **Slower Desktop Auto-Advance** – Carousel auto-advance is now 12s on desktop (Linux/Windows/macOS) vs 5s on mobile, and pauses when the carousel scrolls off-screen.
- **Layout Fix** – Dot indicators repositioned fully below the action buttons with a clear gap; title raised so the action row no longer overlaps the dots.

### 🏠 Home / Explore
- **Section Accent Bars** – Every section title now shows a slim 4px gradient accent bar (primary → tertiary → secondary).

### 🧩 Icons
- **Icon System Audit** – All 143 used icons now resolve to real bundled assets (4500+ SVGs). Fixed mappings for `bookmark-border`/`bookmark-outline` → `bookmark-02`, `delete-sweep` → `delete-01`, `queue` → `check-list`, and `swap-horiz` → `exchange-01`; removed duplicate override keys.

---

## [3.5.0] - Experience & Navigation Overhaul

### 🏠 Home Screen
- **Netflix-Style Banner** – Cinematic hero banner with a three-button action row (Bookmark / Play / Info).
- **Continue Watching** – Resume progress cards with improved layout and watch-progress updates.
- **Collapsible Sections** – Tap section titles (Continue Watching, Trending, etc.) to collapse/expand with animated chevron rotation.
- **No-Provider Icon Wobble** – Items without a provider source play a subtle ±6° wobble to draw attention.
- **Retry Button Spin** – Error "Try Again" button spins 360° before retrying.
- **Gradient Dividers & Improved Empty States** – Section separators fade from primary color; empty states feature circular icon containers with guidance text.
- **Storage Info Bar** – Free-space indicator shown in the library.

### 📚 Library Screen
- **Queue Tab** – New dedicated queue management tab.
- **Grid/List Toggle** – Switch between poster grid and compact list layouts.
- **Bookmarks Float Animation** – Empty-state icon floats up and down (±4px, 3s cycle).
- **Downloads Slide-to-Delete** – `Dismissible` swipe-to-delete with red accent and confirmation dialog.
- **Downloads Status Borders** – Left accent border colored by status: green (completed), orange (in-progress), red (failed).
- **Downloads Pulsing Empty State** – Empty-state icon pulses (1.0→1.08).

### 👤 Profile
- **Profile Avatar & Switch-Account Screen** – Per-profile library/bookmarks/history/tracking with a polished account switcher.
- **Version Info** – App metadata displayed in About.

### 🎬 Details Screen
- **Cast Carousel Staggered Entry** – Cast avatars fade in and slide right with staggered timing.
- **Trailers Play Icon Pulse** – Play overlay pulses (1.0→1.1, 2s repeat).
- **Next Airing Widget Pulse** – Calendar icon pulses (1.0→1.15) for upcoming episodes.
- **Recommendations Staggered Entry** – "More Like This" cards reveal with cinematic stagger.
- **Press Feedback** – Genre chips, provider badges, and Sub/Dub language toggles animate on press; episode sort icon rotates 180° on toggle.
- **Share Buttons** – Quick-share to socials from the details header.

### 🎵 Player Loading Overlay
- **Spinning Ring** – Phase indicator uses a rotating ring (1.5s rotation) instead of a static spinner.

### 🧭 Navigation
- **40px Nav Tabs** – Compact tab bar.
- **Bottom Nav Bounce & Crossfade** – Tab icons bounce to 1.2× (`easeOutBack`) and crossfade on switch.

### 🔍 Search & Explore
- **Staggered Fade-In** – Explore sections and search results fade in with staggered timing.
- **12dp Card Radius** – Softer, modern card corners across grids and lists.

---

## [3.4.6] - Themes, Player & Infrastructure

### 🎨 Theme System Overhaul
- **23 curated themes** – Nature (Ocean default, Forest, Sunset, Arctic, Volcanic), Seasonal (Spring, Autumn, Winter), Brand (Spotify, Discord, Telegram), Palettes (Neon, Deep, Monochrome, Sepia, Pastel), Time-Based (Dawn, Golden Hour, Midnight), Cultural (Wabi-Sabi, Indian Vibrant, Moroccan), Pure (AMOLED Black).
- Removed 30 legacy themes in favor of the curated collection.

### 📺 Media Player & Subtitles
- **Subtitle Styling** – Appearance settings, custom shadows, and text scaling.
- **Custom Player Seek Bar** – Refactored progress bar with 30-second seek step.
- **Netflix-Style Scrim** – Subtle overlay scrim on TV/Desktop for control readability.
- **Dub Status Filtering** – Filter episodes by sub/dub in the side panel, with visual dub badges.

### 🔗 Integrations & Tracking
- **AniList Sync & Metadata** – Full AniList tracking plus TMDB metadata enrichment.
- **Multi-tracker support** – Trakt, Simkl, MAL, AniList.

### ⚙️ Settings
- **Collapsible Groups** – Settings groups collapse/expand with animated chevrons and section descriptions.
- **Theme Selector Grid** – Responsive swatch grid with border highlight on selection.
- **About Info Cards** – Version, package, and SDK metadata in organized cards.

### 🛠️ Infrastructure & CI/CD
- **Multi-platform release pipeline** – GitHub Actions with per-platform build jobs: Android (split + universal APK), Windows (EXE/Inno Setup), Linux (deb/rpm/tar.xz), macOS (DMG), iOS (IPA + xcarchive).
- **MixPlug Plugin System** – Inline plugin install via `installer.sh` (fetches `repo.json` → `plugins.json`, extracts `.mix` zips with `meta.json`); one-command `mixstream` install + clean uninstaller.
- **Preview Workflow** – Auto-generates a release keystore if the signing secret is missing.
- **Single Author History & Dual Remote Push** – Rewritten to `alwayszihan`, force-pushed to GitHub and Codeberg.

### 🐞 Bug Fixes
- Fixed vertical scroll jitter on recommendations and search screen scroll bugs.
- Fixed AniList logo assets, player padding, and Anilist enrichment failures.
- Resolved Cloudflare cookie bypass and proxy header injection.
- Fixed all 81 static-analysis lint issues (now 0) and the `_InfoEntry` private-type-in-public-API warning.

---

## Roadmap

- **Android TV** deep-layout support and focused navigation.
- **iOS / macOS** builds.
- **CloudStream plugin compatibility** investigation (own JS plugins are the priority).
- **Release signing** for distribution builds.

---

### 👤 Contributors

- alwayszihan
