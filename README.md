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

## 🚀 Key Features

- 📱 **Cross-platform**: Android, Android TV, iOS, Windows, macOS, Linux
- 🔌 **Plugin-based architecture** with custom JavaScript engine
- 🔍 **Powerful search & discovery** with TMDB integration
- 🌐 **Multi-provider support** with domain switching
- 🎬 **Advanced streaming controls** - playback speed, resume, quality selection
- 🔗 **Multi-tracker sync** - Trakt, Simkl, MAL, AniList
- 🌍 **40+ languages** with smart skip (Intro/Outro) support
- 📺 **Live streaming** with improved reliability
- ⏱️ **Offline viewing** with download support

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
| **Android TV** | ⏳ Coming soon    |
| **iOS**        | ⏳ Coming soon    |
| **macOS**      | ⏳ Coming soon    |

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


## 📚 Learn More

- **GitHub Issues**: Report bugs or request features
- **Translation Guide**: Help with localization
- **Extension Guide**: Build your own plugins

## 🤝 Contributing

We welcome all kinds of contributions! Whether fixing bugs or adding features.

## 📊 Project Stats

<div align="center">

<img height="160" alt="stats" src="https://github-readme-stats.vercel.app/api?username=alwayszihanx&show_icons=true&theme=github_dark&hide_border=true&include_all_commits=true&count_private=true" />

<img height="160" alt="top langs" src="https://github-readme-stats.vercel.app/api/top-langs/?username=alwayszihanx&layout=compact&theme=github_dark&hide_border=true" />

<img height="160" alt="streak" src="https://github-readme-streak-stats.herokuapp.com/?user=alwayszihanx&theme=github-dark-blue&hide_border=true" />

</div>
