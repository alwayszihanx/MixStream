# Changelog

All notable changes to MixStream are documented here. The format loosely follows [Keep a Changelog](https://keepachangelog.com/).

---

## [3.6.9] - Latest

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

