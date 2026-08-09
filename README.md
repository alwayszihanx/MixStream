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
  <a href="https://github.com/alwayszihanx/mixstream/issues?q=is%3Aissue+is%3Aclosed">
    <img src="https://img.shields.io/github/issues-search/alwayszihanx/mixstream?query=is%3Aissue+is%3Aclosed&style=for-the-badge&color=2ecc71" />
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

## ✨ Recent Highlights (v3.6.x)

- 🎨 **Custom loading indicators** – A hand-crafted dot-pulse loader (glowing dots travel in a wave around a ring) replaces the stock Material spinner across every screen: home, search, library, extensions, settings, details, player, and splash. A compact `.small` variant is used for thumbnails and account switching.
- 💾 **Hero bookmark button** – The hero's "Save" placeholder is now a real per-profile **Bookmark/Bookmarked** toggle wired to your library. Saved items show a filled accent-colored bookmark.
- 🖥️ **Slimmer desktop title bar** – Reduced to 36px with compact 14px icons for close, fullscreen, and always-on-top controls.
- 📺 **Hero carousel polish** – Disney-style gradient titles (white → primary → tertiary), slower auto-advance on desktop (12s) with auto-pause when off-screen, and dot indicators repositioned below the action buttons.
- 🔤 **Section accent bars** – Every section title now gets a slim gradient accent bar (primary → tertiary → secondary).
- 🧩 **Icon system audit** – All 143 used icons now resolve to real bundled assets; bookmark, queue, swap, and delete-sweep mappings were fixed.

## 🚀 Key Features

- 📱 **Cross-platform**: Android, Windows, Linux (Android TV / iOS / macOS on the roadmap)
- 🔌 **Plugin-based architecture** with a custom JavaScript engine — install community extensions (`.mix` / `.js`) to add sources
- 🔍 **Powerful search & discovery** with TMDB integration
- 🌐 **Multi-provider support** with domain switching and Cloudflare cookie bypass
- 🎬 **Advanced streaming controls** — playback speed, resume, quality selection, custom seek bar
- 🧭 **Multi-profile support** — per-profile library, bookmarks, history, and tracking
- 🔗 **Multi-tracker sync** — Trakt, Simkl, MAL, AniList
- 🌍 **40+ languages** with smart skip (Intro/Outro) support
- 📺 **Live streaming** with improved reliability
- ⏱️ **Offline viewing** with download support
- 🎨 **23 curated themes** (Ocean default, AMOLED Black, Synthwave, and more) plus dynamic color
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
| **iOS**         |✅ [ Sideloading] |
| **macOS**      |✅                |

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

### 🐧 Linux

**⚡ One-command install (app + all MixPlug plugins):**

```bash
curl -fsSL https://raw.githubusercontent.com/alwayszihanx/MixStream/main/installer.sh | sudo bash
```

This installs MixStream **and** automatically installs all plugins from the MixPlug repository, so extensions are ready on first launch.

**🗑️ One-command uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/alwayszihanx/MixStream/main/uninstaller.sh | sudo bash
```

The installer automatically uses the local bundle if available, or downloads it from GitHub Releases.

### 💻 Windows

1. Download `mixstream.exe` from Releases
2. Install and run the application

### 🍏 iOS / macOS

Coming soon...

## 🛠️ Build from Source

```bash
git clone https://github.com/alwayszihanx/mixstream.git
cd mixstream
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## 🧩 Building Your Own Plugins

MixStream extensions are plain JavaScript bundled as `.mix` packages (or raw `.js`). The runtime provides `fetch`, `getPreference`/`setPreference`, `magic_m3u8`, and proxy helpers (`MAGIC_PROXY_v1`/`v2`). Extensions implement the `MixStreamProvider` contract (`search`, `getHome`, `getDetails`, `loadStreams`).

See the **[Plugin Development Guide](PLUGIN_DEVELOPMENT_GUIDE.md)** for details.

## 📚 Learn More

- **GitHub Issues**: Report bugs or request features
- **Translation Guide**: Help with localization
- **Extension Guide**: Build your own plugins

## 🤝 Contributing

We welcome all kinds of contributions! Whether fixing bugs or adding features. See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📊 Project Stats

<div align="center">

<img height="160" alt="stats" src="https://github-readme-stats.vercel.app/api?username=alwayszihanx&show_icons=true&theme=github_dark&hide_border=true&include_all_commits=true&count_private=true" />

<img height="160" alt="top langs" src="https://github-readme-stats.vercel.app/api/top-langs/?username=alwayszihanx&layout=compact&theme=github_dark&hide_border=true" />

<img height="160" alt="streak" src="https://github-readme-streak-stats.herokuapp.com/?user=alwayszihanx&theme=github-dark-blue&hide_border=true" />

</div>
