# Changelog

All notable changes to MixStream are documented here. The format loosely follows [Keep a Changelog](https://keepachangelog.com/).

---

## [3.6.8] - Latest

### 🎬 Cinematic Details Page
- **Complete redesign** – The details screen was rebuilt from the ground up with a cinematic editorial layout: a rounded hero card with parallax, a dark gradient scrim, and a floating glass action panel (title, metadata, play/download, tags).
- **Bigger back button** – The back control is now a prominent 46px circular button with a black translucent backdrop so it's always visible over the artwork.
- **Desktop/TV two-panel hero** – A large rounded backdrop panel with overlaid title and metadata sits beside a floating poster + action column for a magazine-style layout.
- **Premium section tabs** – A segmented control (rounded track with hover pills) replaces the plain pill row for Episodes / Cast / Trailers / More Like This.
- **Editorial synopsis** – Synopsis now opens each section with a gradient accent bar; error and loading states are wrapped in rounded cards.

### 🧭 Floating Pill Navigation
- The bottom tab bar was replaced with a **fully rounded pill** (32px radius) with a gradient surface, primary-tinted border, and soft glow shadows.
- Active items sit in their own glowing pill (20px radius) with a spring `easeOutBack` scale animation.
- The widescreen sidebar dock is now a rounded 28px container to match.

### 🏠 First-Run Onboarding
- Added a 3-slide welcome flow (Stream your favorites / Powered by extensions / Watch offline) with dot indicators and a primary CTA.
- The router now routes to `/onboarding` on first launch and remembers completion per app install.

### 📚 Library Redesign
- Tabs reordered to **Continue Watching | My List | Downloads | Queue**.
- New Continue Watching tab feeds items with 0–98% progress, newest first, with a grid on large screens and a list on mobile plus an empty state.

### 🌞 Solarized Default Theme
- Fresh installs now boot into the curated **Solarized** theme (config index 23) instead of Netflix; saved preferences are preserved on upgrade.

### 🎨 Design System Polish
- Consistent corner radii: floating nav 32, cards 16, buttons 14–16, sheets/dialogs 24–28.
- Gradient accent bars (primary → tertiary → secondary) on section headers.
- Home section headers use themed text color; synced progress cards use rounded 12px corners.
- Settings tile icons and hero action buttons, header arrows, and provider chips all rounded to spec.

---