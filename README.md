# MixStream

<div align="center">
    <img src="assets/images/icon.png" alt="MixStream Logo" height="120" />
    <h2>MixStream</h2>
</div>

<div align="center">
  <a href="https://github.com/alwayszihanx/mixstream/releases">
    <img src="https://img.shields.io/github/downloads/alwayszihanx/mixstream/total?style=for-the-badge&color=1f6feb" />
  </a>
  <a href="https://github.com/alwayszihanx/mixstream/stargazers">
    <img src="https://img.shields.io/github/stars/alwayszihanx/mixstream?style=for-the-badge&color=f1c40f" />
  </a>
  <a href="https://github.com/alwayszihanx/mixstream/releases">
    <img src="https://img.shields.io/github/v/release/alwayszihanx/mixstream?style=for-the-badge&color=f39c12" />
  </a>
  <a href="https://github.com/alwayszihanx/mixstream/issues">
    <img src="https://img.shields.io/github/issues/alwayszihanx/mixstream?style=for-the-badge&color=e74c3c" />
  </a>
  <a href="https://github.com/alwayszihanx/mixstream/commits/main">
    <img src="https://img.shields.io/github/last-commit/alwayszihanx/mixstream?style=for-the-badge&color=17a2b8" />
  </a>
</div>

<p align="center">
  <br>
  <strong>A modern, cross-platform media streaming client inspired by CloudStream</strong>
  <br>
</p>

<div align="center">

**⚠️ Important Warning**: By default, this app doesn't provide any video sources; you have to install extensions to add functionality to the app.

> **Note**: This project is an independent application built with Flutter. While it supports similar extension formats, it is a simplified, modern re-imagining and is **not** a direct clone or fork of the official CloudStream client.

**Please don't create illegal extensions or use any that host any copyrighted media.** This project does not condone copyright infringement.

</div>

## ✨ Highlights (v3.6.8)

- 🎬 **Cinematic details page** – Fully redesigned with a rounded parallax hero card, floating glass action panel, a prominent circular back button, and a two-panel editorial layout for desktop/TV.
- 🧭 **Floating pill navigation** – A gradient pill-shaped nav bar with glowing active states replaces the stock tab bar; the widescreen sidebar uses a rounded 28px dock.
- 🏠 **First-run onboarding** – A 3-slide welcome flow introduces streaming, extensions, and offline downloads before the app opens.
- 📚 **Rebuilt Library tabs** – Continue Watching | My List | Downloads | Queue, with a smarter continue-watching feed (progress 0–98%).
- 🌞 **Solarized default theme** – Fresh installs now boot into the curated Solarized theme.
- 🎨 **Design system polish** – 32px pill nav, rounded cards, gradient section accent bars, and consistent corner radii across the app.

## 🚀 Key Features

- 📱 **Cross-platform**: Android, Windows, Linux, Android TV, iOS (sideloading), macOS
- 🔌 **Plugin-based architecture** with a custom JavaScript engine — install community extensions (`.mix` / `.js`) to add sources
- 🔍 **Powerful search & discovery** with TMDB integration
- 🌐 **Multi-provider support** with domain switching and Cloudflare cookie bypass
- 🎬 **Advanced streaming controls** — playback speed, resume, quality selection, custom seek bar
- 🧭 **Multi-profile support** — per-profile library, bookmarks, history, and tracking
- 🔗 **Multi-tracker sync** — Trakt, Simkl, MAL, AniList
- 🌍 **40+ languages** with smart skip (Intro/Outro) support
- 📺 **Live streaming** with improved reliability
- ⏱️ **Offline viewing** with download support
- 🎨 **23 curated themes** (Solarized default, AMOLED Black, Synthwave, and more) plus dynamic color
- 🎞️ **Netflix-style experience** — cinematic hero banner, carousels, cast/staff, trailers, recommendations
- 🎵 **Torrent streaming** support
- 📥 **Queue tab** and **Continue Watching** for picking up where you left off

## 🛠️ Built With

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Riverpod-%232D3748.svg?style=for-the-badge&logo=riverpod&logoColor=white" />
  <img src="https://img.shields.io/badge/Hive-%23DE3027.svg?style=for-the-badge&logo=hive&logoColor=white" />
  <img src="https://img.shields.io/badge/quick_js_ng-%23F39C12.svg?style=for-the-badge&logo=javascript&logoColor=white" />
</p>

## 📱 Supported Platforms

| Platform       | Support          |
|:-------        |:----------------:|
| **Android**    | ✅                |
| **Windows**    | ✅                |
| **Linux**      | ✅                |
| **Android TV** | ✅                |
| **iOS**        | ✅ [Sideloading] |
| **macOS**      | ✅                |

## 🎨 Screenshots

### 📱 Mobile

<p align="center">
  <img src="screenshots/mobile/home.png" width="250" />
  <img src="screenshots/mobile/discover.png" width="250" />
  <img src="screenshots/mobile/details.png" width="250" />
  <img src="screenshots/mobile/settings.png" width="250" />
</p>

### 📺 Large Screen

<p align="center">
  <img src="screenshots/tv/details_1.png" width="500" />
  <img src="screenshots/tv/details_2.png" width="500" />
</p>

## 📥 Installation

### 🤖 Android

Download the latest APK from the **[Releases page](https://github.com/alwayszihanx/mixstream/releases/latest)** and install it on your device.

### 💻 Windows

1. Download `mixstream.exe` from Releases
2. Install and run the application

### 🐧 Linux

Download the `.deb`, `.rpm`, or `.tar.xz` package from Releases and install it with your package manager.

### 🍏 iOS / macOS

Available via sideloading / DMG from Releases.

## 🛠️ Build from Source

```bash
git clone https://github.com/alwayszihanx/mixstream.git
cd mixstream
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run
```

> **Note**: Release APKs from local builds are debug-signed (no `android/key.properties`), which is fine for installing on your own device but not for publishing.

## 🧩 Building Your Own Plugins

MixStream extensions are plain JavaScript bundled as `.mix` packages (or raw `.js`). The runtime provides `fetch`, `getPreference`/`setPreference`, `magic_m3u8`, and proxy helpers (`MAGIC_PROXY_v1`/`v2`). Extensions implement the `MixStreamProvider` contract (`search`, `getHome`, `getDetails`, `loadStreams`).

## 🤝 Contributing

We welcome all kinds of contributions! Whether fixing bugs or adding features, feel free to open a PR.

## 📊 Project Stats

<div align="center">

<img height="160" alt="stats" src="https://github-readme-stats.vercel.app/api?username=alwayszihanx&show_icons=true&theme=github_dark&hide_border=true&include_all_commits=true&count_private=true" />

<img height="160" alt="top langs" src="https://github-readme-stats.vercel.app/api/top-langs/?username=alwayszihanx&layout=compact&theme=github_dark&hide_border=true" />

<img height="160" alt="streak" src="https://github-readme-streak-stats.herokuapp.com/?user=alwayszihanx&theme=github-dark-blue&hide_border=true" />

</div>