# Contributing to MixStream

First off, thank you for considering contributing to MixStream! It's people like you who make MixStream a better tool for everyone.

This guide will help you get started with setting up the project on your local machine and understanding the development workflow.

---

## 🛠️ Getting Started

### Prerequisites

To build MixStream from source, you need the following installed on your machine:

1.  **Flutter SDK**: Version `3.10.4` or higher is required.
    - [Download Flutter](https://docs.flutter.dev/get-started/install)
2.  **Dart SDK**: Included with Flutter.
3.  **Git**: For version control.
4.  **IDE**: We recommend [VS Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio) with the Flutter and Dart plugins.

### Installation & Setup

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/alwayszihanx/MixStream.git
    cd mixstream
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Generate Localization classes**:
    MixStream uses the `intl` package for internationalization. Run this command to generate the necessary Dart classes from our `.arb` files:
    ```bash
    flutter gen-l10n
    ```

4.  **Generate Code**:
    MixStream uses Riverpod and other code generators. Since generated files are not tracked in Git, you must run this command after cloning or pulling changes:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
    *Tip: Use `dart run build_runner watch` to automatically regenerate code when you save changes.*

5.  **Run the app**:
    Ensure you have an emulator running or a physical device connected.
    ```bash
    flutter run
    ```

---

## 📂 Project Structure

MixStream follows a feature-first architecture combined with standard clean architecture layers:

-   `lib/core/`: Contains core services, network logic, database (Hive) schemas, and shared providers.
-   `lib/features/`: Contains the main application features (Home, Search, Discover, Settings, etc.).
    -   Each feature is split into `presentation` (UI), `domain` (models), and `data` (repositories).
-   `lib/l10n/`: All localization files (`.arb`).
-   `packages/`: Internal packages and plugins used by the app.
-   `assets/`: Static assets like images and bundled icons.

---

## 💻 Development Workflow

### Coding Standards

We use `flutter_lints` and some additional rules to ensure code quality. Before submitting a Pull Request, please ensure:

-   **Linting**: Run `flutter analyze` to check for issues.
-   **Formatting**: Run `dart format .` to format the code consistently.
-   **Best Practices**:
    -   Use `const` constructors where possible.
    -   Avoid using `print()` for debugging; use a logging framework or `debugPrint`.
    -   Keep UI components modular and reusable.
    -   Follow [Riverpod](https://riverpod.dev/) best practices for state management.

### Branching & Pull Requests

1.  **Create a branch**: Use a descriptive name like `feat/new-ui-element` or `fix/search-bug`.
2.  **Commit often**: Keep your commits small and descriptive.
3.  **Pull Request**: Provide a clear description of what your changes do and reference any related issues.

---

## 🐞 Issues & Community

If you find a bug or have a feature request, please use our community channels:

-   **GitHub Issues**: [Open an issue here](https://github.com/alwayszihanx/MixStream/issues). This is our primary tracker for bugs and technical tasks.
-   **Discord server**: Join the discussion on [Discord](https://discord.gg/73XGA8Mxn9).
-   **Telegram Channel**: Stay updated via [Telegram](https://t.me/+Ez5Vsv2pUUFjZmNl).

Please check for existing issues before creating a new one to avoid duplicates.

---

## 📖 Other Guides

-   **[CONTRIBUTING_TRANSLATIONS.md](CONTRIBUTING_TRANSLATIONS.md)**: specifically for helping with app translations (over 40 languages supported!).
-   **[PLUGIN_DEVELOPMENT_GUIDE.md](PLUGIN_DEVELOPMENT_GUIDE.md)**: specifically for creating and publishing your own MixStream extensions.

---

Thank you for contributing! 🚀
