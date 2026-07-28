import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

extension _ColorExt on Color {
  int _r() => (r * 255.0).round().clamp(0, 255);
  int _g() => (g * 255.0).round().clamp(0, 255);
  int _b() => (b * 255.0).round().clamp(0, 255);
  int _a() => (a * 255.0).round().clamp(0, 255);

  Color darken(double amount) {
    return Color.fromARGB(
      _a(),
      (_r() - (_r() * amount)).round().clamp(0, 255),
      (_g() - (_g() * amount)).round().clamp(0, 255),
      (_b() - (_b() * amount)).round().clamp(0, 255),
    );
  }

  Color lighten(double amount) {
    final remaining = 1.0 - amount;
    return Color.fromARGB(
      _a(),
      (255 - (255 - _r()) * remaining).round().clamp(0, 255),
      (255 - (255 - _g()) * remaining).round().clamp(0, 255),
      (255 - (255 - _b()) * remaining).round().clamp(0, 255),
    );
  }

  Color compositeOver(Color background) {
    final srcAlpha = a;
    final dstAlpha = background.a;
    final outAlpha = srcAlpha + dstAlpha * (1 - srcAlpha);
    if (outAlpha == 0) return background;
    return Color.fromARGB(
      (outAlpha * 255).round(),
      ((_r() / 255.0 * srcAlpha + background._r() / 255.0 * dstAlpha * (1 - srcAlpha)) / outAlpha).round().clamp(0, 255),
      ((_g() / 255.0 * srcAlpha + background._g() / 255.0 * dstAlpha * (1 - srcAlpha)) / outAlpha).round().clamp(0, 255),
      ((_b() / 255.0 * srcAlpha + background._b() / 255.0 * dstAlpha * (1 - srcAlpha)) / outAlpha).round().clamp(0, 255),
    );
  }
}

class ThemeConfig {
  final String displayName;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondaryLight;
  final Color secondaryDark;
  final Color tertiaryLight;
  final Color tertiaryDark;
  final Color backgroundLight;
  final Color backgroundDark;
  final Color surfaceLight;
  final Color surfaceDark;
  final Color textLight;
  final Color textDark;
  final bool isDynamic;

  const ThemeConfig({
    required this.displayName,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondaryLight,
    required this.secondaryDark,
    required this.tertiaryLight,
    required this.tertiaryDark,
    required this.backgroundLight,
    required this.backgroundDark,
    required this.surfaceLight,
    required this.surfaceDark,
    required this.textLight,
    required this.textDark,
    this.isDynamic = false,
  });

  ColorScheme getLightColorScheme() {
    return ColorScheme.light(
      primary: primaryLight,
      onPrimary: Colors.white,
      primaryContainer: primaryLight.withValues(alpha: 0.24).compositeOver(Colors.white),
      onPrimaryContainer: primaryLight.darken(0.35),
      secondary: secondaryLight,
      onSecondary: Colors.white,
      secondaryContainer: secondaryLight.withValues(alpha: 0.24).compositeOver(Colors.white),
      onSecondaryContainer: secondaryLight.darken(0.35),
      tertiary: tertiaryLight,
      onTertiary: Colors.white,
      tertiaryContainer: tertiaryLight.withValues(alpha: 0.24).compositeOver(Colors.white),
      onTertiaryContainer: tertiaryLight.darken(0.35),
      error: const Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF93000A),
      background: backgroundLight,
      surface: surfaceLight,
      onSurface: textLight,
      surfaceVariant: primaryLight.withValues(alpha: 0.14).compositeOver(surfaceLight),
      onSurfaceVariant: textLight.withValues(alpha: 0.75),
      outline: secondaryLight.withValues(alpha: 0.6).compositeOver(const Color(0xFF79747E)),
      outlineVariant: primaryLight.withValues(alpha: 0.20).compositeOver(const Color(0xFFCAC4D0)),
      inverseSurface: backgroundDark,
      onInverseSurface: const Color(0xFFF4EFF4),
      inversePrimary: primaryDark,
    );
  }

  ColorScheme getDarkColorScheme() {
    return ColorScheme.dark(
      primary: primaryDark,
      onPrimary: primaryLight.darken(0.5),
      primaryContainer: primaryLight.darken(0.2),
      onPrimaryContainer: primaryDark.lighten(0.15),
      secondary: secondaryDark,
      onSecondary: secondaryLight.darken(0.5),
      secondaryContainer: secondaryLight.darken(0.2),
      onSecondaryContainer: secondaryDark.lighten(0.15),
      tertiary: tertiaryDark,
      onTertiary: tertiaryLight.darken(0.5),
      tertiaryContainer: tertiaryLight.darken(0.2),
      onTertiaryContainer: tertiaryDark.lighten(0.15),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      background: backgroundDark,
      surface: surfaceDark,
      onSurface: textDark,
      surfaceVariant: primaryDark.withValues(alpha: 0.18).compositeOver(surfaceDark),
      onSurfaceVariant: textDark.withValues(alpha: 0.65),
      outline: secondaryDark.withValues(alpha: 0.5).compositeOver(const Color(0xFF938F99)),
      outlineVariant: primaryDark.withValues(alpha: 0.22).compositeOver(const Color(0xFF49454F)),
      inverseSurface: backgroundLight,
      onInverseSurface: const Color(0xFF313033),
      inversePrimary: primaryLight,
    );
  }

  ColorScheme getAmoledColorScheme() => getDarkColorScheme().copyWith(
    background: Colors.black,
    surface: Colors.black,
    surfaceVariant: primaryDark.withValues(alpha: 0.08).compositeOver(const Color(0xFF1A1A1A)),
    onSurface: textDark,
  );
}

const List<ThemeConfig> allThemes = [
  ThemeConfig(
    displayName: 'Solarized Dark',
    primaryLight: Color(0xFF268BD2),
    primaryDark: Color(0xFF268BD2),
    secondaryLight: Color(0xFF2AA198),
    secondaryDark: Color(0xFF2AA198),
    tertiaryLight: Color(0xFFB58900),
    tertiaryDark: Color(0xFFB58900),
    backgroundLight: Color(0xFFFDF6E3),
    backgroundDark: Color(0xFF002B36),
    surfaceLight: Color(0xFFEEE8D5),
    surfaceDark: Color(0xFF073642),
    textLight: Color(0xFF657B83),
    textDark: Color(0xFFEEE8D5),
  ),
  ThemeConfig(
    displayName: 'Dracula',
    primaryLight: Color(0xFFBD93F9),
    primaryDark: Color(0xFFBD93F9),
    secondaryLight: Color(0xFFFF79C6),
    secondaryDark: Color(0xFFFF79C6),
    tertiaryLight: Color(0xFF50FA7B),
    tertiaryDark: Color(0xFF50FA7B),
    backgroundLight: Color(0xFFF8F8F2),
    backgroundDark: Color(0xFF282A36),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF44475A),
    textLight: Color(0xFF282A36),
    textDark: Color(0xFFF8F8F2),
  ),
  ThemeConfig(
    displayName: 'Solarized Light',
    primaryLight: Color(0xFF268BD2),
    primaryDark: Color(0xFF268BD2),
    secondaryLight: Color(0xFF2AA198),
    secondaryDark: Color(0xFF2AA198),
    tertiaryLight: Color(0xFFB58900),
    tertiaryDark: Color(0xFFB58900),
    backgroundLight: Color(0xFFFDF6E3),
    backgroundDark: Color(0xFF002B36),
    surfaceLight: Color(0xFFEEE8D5),
    surfaceDark: Color(0xFF073642),
    textLight: Color(0xFF657B83),
    textDark: Color(0xFFEEE8D5),
  ),
  ThemeConfig(
    displayName: 'Nord',
    primaryLight: Color(0xFF5E81AC),
    primaryDark: Color(0xFF5E81AC),
    secondaryLight: Color(0xFF88C0D0),
    secondaryDark: Color(0xFF88C0D0),
    tertiaryLight: Color(0xFFB48EAD),
    tertiaryDark: Color(0xFFB48EAD),
    backgroundLight: Color(0xFFECEFF4),
    backgroundDark: Color(0xFF2E3440),
    surfaceLight: Color(0xFFD8DEE9),
    surfaceDark: Color(0xFF3B4252),
    textLight: Color(0xFF2E3440),
    textDark: Color(0xFFECEFF4),
  ),
  ThemeConfig(
    displayName: 'Catppuccin Mocha',
    primaryLight: Color(0xFF89B4FA),
    primaryDark: Color(0xFF89B4FA),
    secondaryLight: Color(0xFFA6E3A1),
    secondaryDark: Color(0xFFA6E3A1),
    tertiaryLight: Color(0xFFF5C2E7),
    tertiaryDark: Color(0xFFF5C2E7),
    backgroundLight: Color(0xFFEFF1F5),
    backgroundDark: Color(0xFF1E1E2E),
    surfaceLight: Color(0xFFCCD0DA),
    surfaceDark: Color(0xFF313244),
    textLight: Color(0xFF4C4F69),
    textDark: Color(0xFFCDD6F4),
  ),
  ThemeConfig(
    displayName: 'Catppuccin Macchiato',
    primaryLight: Color(0xFF8AADF4),
    primaryDark: Color(0xFF8AADF4),
    secondaryLight: Color(0xFFA6DA95),
    secondaryDark: Color(0xFFA6DA95),
    tertiaryLight: Color(0xFFF5BDE6),
    tertiaryDark: Color(0xFFF5BDE6),
    backgroundLight: Color(0xFFEFF1F5),
    backgroundDark: Color(0xFF24273A),
    surfaceLight: Color(0xFFCCD0DA),
    surfaceDark: Color(0xFF363A4F),
    textLight: Color(0xFF4C4F69),
    textDark: Color(0xFFCAD3F5),
  ),
  ThemeConfig(
    displayName: 'Catppuccin Latte',
    primaryLight: Color(0xFF1E66F5),
    primaryDark: Color(0xFF1E66F5),
    secondaryLight: Color(0xFF40A02B),
    secondaryDark: Color(0xFF40A02B),
    tertiaryLight: Color(0xFFEA76CB),
    tertiaryDark: Color(0xFFEA76CB),
    backgroundLight: Color(0xFFEFF1F5),
    backgroundDark: Color(0xFF1E1E2E),
    surfaceLight: Color(0xFFCCD0DA),
    surfaceDark: Color(0xFF313244),
    textLight: Color(0xFF4C4F69),
    textDark: Color(0xFFCDD6F4),
  ),
  ThemeConfig(
    displayName: 'One Dark',
    primaryLight: Color(0xFF61AFEF),
    primaryDark: Color(0xFF61AFEF),
    secondaryLight: Color(0xFF98C379),
    secondaryDark: Color(0xFF98C379),
    tertiaryLight: Color(0xFFE5C07B),
    tertiaryDark: Color(0xFFE5C07B),
    backgroundLight: Color(0xFFFAFBFC),
    backgroundDark: Color(0xFF282C34),
    surfaceLight: Color(0xFFE1E4E8),
    surfaceDark: Color(0xFF3E4451),
    textLight: Color(0xFF24292E),
    textDark: Color(0xFFABB2BF),
  ),
  ThemeConfig(
    displayName: 'Monokai',
    primaryLight: Color(0xFFA6E22E),
    primaryDark: Color(0xFFA6E22E),
    secondaryLight: Color(0xFFFD971F),
    secondaryDark: Color(0xFFFD971F),
    tertiaryLight: Color(0xFFF92672),
    tertiaryDark: Color(0xFFF92672),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF272822),
    surfaceLight: Color(0xFFE8E8E8),
    surfaceDark: Color(0xFF3E3D32),
    textLight: Color(0xFF272822),
    textDark: Color(0xFFF8F8F2),
  ),
  ThemeConfig(
    displayName: 'Gruvbox Dark',
    primaryLight: Color(0xFFFABD2F),
    primaryDark: Color(0xFFFABD2F),
    secondaryLight: Color(0xFF8EC07C),
    secondaryDark: Color(0xFF8EC07C),
    tertiaryLight: Color(0xFFFB4934),
    tertiaryDark: Color(0xFFFB4934),
    backgroundLight: Color(0xFFFBF1C7),
    backgroundDark: Color(0xFF282828),
    surfaceLight: Color(0xFFEBDBB2),
    surfaceDark: Color(0xFF3C3836),
    textLight: Color(0xFF3C3836),
    textDark: Color(0xFFEBDBB2),
  ),
  ThemeConfig(
    displayName: 'Gruvbox Light',
    primaryLight: Color(0xFFD79921),
    primaryDark: Color(0xFFD79921),
    secondaryLight: Color(0xFF689D6A),
    secondaryDark: Color(0xFF689D6A),
    tertiaryLight: Color(0xFFCC241D),
    tertiaryDark: Color(0xFFCC241D),
    backgroundLight: Color(0xFFFBF1C7),
    backgroundDark: Color(0xFF282828),
    surfaceLight: Color(0xFFEBDBB2),
    surfaceDark: Color(0xFF3C3836),
    textLight: Color(0xFF3C3836),
    textDark: Color(0xFFEBDBB2),
  ),
  ThemeConfig(
    displayName: 'Material Dark',
    primaryLight: Color(0xFF80CBC4),
    primaryDark: Color(0xFF80CBC4),
    secondaryLight: Color(0xFF82B1FF),
    secondaryDark: Color(0xFF82B1FF),
    tertiaryLight: Color(0xFFFFB74D),
    tertiaryDark: Color(0xFFFFB74D),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF263238),
    surfaceLight: Color(0xFFF5F5F5),
    surfaceDark: Color(0xFF37474F),
    textLight: Color(0xFF212121),
    textDark: Color(0xFFECEFF1),
  ),
  ThemeConfig(
    displayName: 'Material Light',
    primaryLight: Color(0xFF6200EE),
    primaryDark: Color(0xFF6200EE),
    secondaryLight: Color(0xFF03DAC6),
    secondaryDark: Color(0xFF03DAC6),
    tertiaryLight: Color(0xFF018786),
    tertiaryDark: Color(0xFF018786),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF263238),
    surfaceLight: Color(0xFFFFFFFF),
    surfaceDark: Color(0xFF37474F),
    textLight: Color(0xFF212121),
    textDark: Color(0xFFECEFF1),
  ),
  ThemeConfig(
    displayName: 'Tokyo Night',
    primaryLight: Color(0xFF7AA2F7),
    primaryDark: Color(0xFF7AA2F7),
    secondaryLight: Color(0xFFBB9AF7),
    secondaryDark: Color(0xFFBB9AF7),
    tertiaryLight: Color(0xFF9ECE6A),
    tertiaryDark: Color(0xFF9ECE6A),
    backgroundLight: Color(0xFFF0F1F5),
    backgroundDark: Color(0xFF1A1B26),
    surfaceLight: Color(0xFFD5D6DB),
    surfaceDark: Color(0xFF24283B),
    textLight: Color(0xFF1A1B26),
    textDark: Color(0xFFC0CAF5),
  ),
  ThemeConfig(
    displayName: 'Tokyo Night Storm',
    primaryLight: Color(0xFF7DCFFF),
    primaryDark: Color(0xFF7DCFFF),
    secondaryLight: Color(0xFFBB9AF7),
    secondaryDark: Color(0xFFBB9AF7),
    tertiaryLight: Color(0xFF9ECE6A),
    tertiaryDark: Color(0xFF9ECE6A),
    backgroundLight: Color(0xFFF0F1F5),
    backgroundDark: Color(0xFF24283B),
    surfaceLight: Color(0xFFD5D6DB),
    surfaceDark: Color(0xFF414868),
    textLight: Color(0xFF1A1B26),
    textDark: Color(0xFFC0CAF5),
  ),
  ThemeConfig(
    displayName: 'GitHub Dark',
    primaryLight: Color(0xFF2F81F7),
    primaryDark: Color(0xFF2F81F7),
    secondaryLight: Color(0xFF3FB950),
    secondaryDark: Color(0xFF3FB950),
    tertiaryLight: Color(0xFFD29922),
    tertiaryDark: Color(0xFFD29922),
    backgroundLight: Color(0xFFFFFFFF),
    backgroundDark: Color(0xFF0D1117),
    surfaceLight: Color(0xFFF6F8FA),
    surfaceDark: Color(0xFF161B22),
    textLight: Color(0xFF24292F),
    textDark: Color(0xFFF0F6FC),
  ),
  ThemeConfig(
    displayName: 'GitHub Light',
    primaryLight: Color(0xFF0969DA),
    primaryDark: Color(0xFF0969DA),
    secondaryLight: Color(0xFF1A7F37),
    secondaryDark: Color(0xFF1A7F37),
    tertiaryLight: Color(0xFF9A6700),
    tertiaryDark: Color(0xFF9A6700),
    backgroundLight: Color(0xFFFFFFFF),
    backgroundDark: Color(0xFF0D1117),
    surfaceLight: Color(0xFFF6F8FA),
    surfaceDark: Color(0xFF161B22),
    textLight: Color(0xFF24292F),
    textDark: Color(0xFFF0F6FC),
  ),
  ThemeConfig(
    displayName: 'Ayu Dark',
    primaryLight: Color(0xFFFFB454),
    primaryDark: Color(0xFFFFB454),
    secondaryLight: Color(0xFF39BAE6),
    secondaryDark: Color(0xFF39BAE6),
    tertiaryLight: Color(0xFFF26D78),
    tertiaryDark: Color(0xFFF26D78),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF0A0E14),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF131721),
    textLight: Color(0xFF0A0E14),
    textDark: Color(0xFFB3B1AD),
  ),
  ThemeConfig(
    displayName: 'Ayu Mirage',
    primaryLight: Color(0xFF5CCFE6),
    primaryDark: Color(0xFF5CCFE6),
    secondaryLight: Color(0xFFFFB454),
    secondaryDark: Color(0xFFFFB454),
    tertiaryLight: Color(0xFFF26D78),
    tertiaryDark: Color(0xFFF26D78),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF1F2430),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF2A2F3A),
    textLight: Color(0xFF1F2430),
    textDark: Color(0xFFCCCAC2),
  ),
  ThemeConfig(
    displayName: 'Everforest Dark',
    primaryLight: Color(0xFFA7C080),
    primaryDark: Color(0xFFA7C080),
    secondaryLight: Color(0xFF7FBBB3),
    secondaryDark: Color(0xFF7FBBB3),
    tertiaryLight: Color(0xFFE67E80),
    tertiaryDark: Color(0xFFE67E80),
    backgroundLight: Color(0xFFFDF6E3),
    backgroundDark: Color(0xFF2B3339),
    surfaceLight: Color(0xFFEFE8D2),
    surfaceDark: Color(0xFF323C41),
    textLight: Color(0xFF5C6A72),
    textDark: Color(0xFFD3C6AA),
  ),
  ThemeConfig(
    displayName: 'Everforest Light',
    primaryLight: Color(0xFF8DA101),
    primaryDark: Color(0xFF8DA101),
    secondaryLight: Color(0xFF7FBBB3),
    secondaryDark: Color(0xFF7FBBB3),
    tertiaryLight: Color(0xFFE67E80),
    tertiaryDark: Color(0xFFE67E80),
    backgroundLight: Color(0xFFFDF6E3),
    backgroundDark: Color(0xFF2B3339),
    surfaceLight: Color(0xFFEFE8D2),
    surfaceDark: Color(0xFF323C41),
    textLight: Color(0xFF5C6A72),
    textDark: Color(0xFFD3C6AA),
  ),
  ThemeConfig(
    displayName: 'Rose Pine',
    primaryLight: Color(0xFFC4A7E7),
    primaryDark: Color(0xFFC4A7E7),
    secondaryLight: Color(0xFFEB6F92),
    secondaryDark: Color(0xFFEB6F92),
    tertiaryLight: Color(0xFFF6C177),
    tertiaryDark: Color(0xFFF6C177),
    backgroundLight: Color(0xFFFAF4ED),
    backgroundDark: Color(0xFF191724),
    surfaceLight: Color(0xFFFFF8F0),
    surfaceDark: Color(0xFF26233A),
    textLight: Color(0xFF575279),
    textDark: Color(0xFFE0DEF4),
  ),
  ThemeConfig(
    displayName: 'Rose Pine Dawn',
    primaryLight: Color(0xFF907AA9),
    primaryDark: Color(0xFF907AA9),
    secondaryLight: Color(0xFFEB6F92),
    secondaryDark: Color(0xFFEB6F92),
    tertiaryLight: Color(0xFFF6C177),
    tertiaryDark: Color(0xFFF6C177),
    backgroundLight: Color(0xFFFAF4ED),
    backgroundDark: Color(0xFF191724),
    surfaceLight: Color(0xFFFFF8F0),
    surfaceDark: Color(0xFF26233A),
    textLight: Color(0xFF575279),
    textDark: Color(0xFFE0DEF4),
  ),
  ThemeConfig(
    displayName: 'Synthwave 84',
    primaryLight: Color(0xFFFF7EDB),
    primaryDark: Color(0xFFFF7EDB),
    secondaryLight: Color(0xFF00D4FF),
    secondaryDark: Color(0xFF00D4FF),
    tertiaryLight: Color(0xFFFFB347),
    tertiaryDark: Color(0xFFFFB347),
    backgroundLight: Color(0xFFF0F0F0),
    backgroundDark: Color(0xFF241B2F),
    surfaceLight: Color(0xFFE0E0E0),
    surfaceDark: Color(0xFF34294F),
    textLight: Color(0xFF241B2F),
    textDark: Color(0xFFF1F1F1),
  ),
  ThemeConfig(
    displayName: 'Cobalt2',
    primaryLight: Color(0xFFFFC600),
    primaryDark: Color(0xFFFFC600),
    secondaryLight: Color(0xFF0088FF),
    secondaryDark: Color(0xFF0088FF),
    tertiaryLight: Color(0xFFFF6D00),
    tertiaryDark: Color(0xFFFF6D00),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF193549),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF234E70),
    textLight: Color(0xFF193549),
    textDark: Color(0xFFFFFFFF),
  ),
  ThemeConfig(
    displayName: 'Night Owl',
    primaryLight: Color(0xFF82AAFF),
    primaryDark: Color(0xFF82AAFF),
    secondaryLight: Color(0xFFC792EA),
    secondaryDark: Color(0xFFC792EA),
    tertiaryLight: Color(0xFFF78C6C),
    tertiaryDark: Color(0xFFF78C6C),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF011627),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF1D3B53),
    textLight: Color(0xFF011627),
    textDark: Color(0xFFD6DEEB),
  ),
  ThemeConfig(
    displayName: 'Horizon',
    primaryLight: Color(0xFFE95678),
    primaryDark: Color(0xFFE95678),
    secondaryLight: Color(0xFFFAB795),
    secondaryDark: Color(0xFFFAB795),
    tertiaryLight: Color(0xFF59C3FF),
    tertiaryDark: Color(0xFF59C3FF),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF1C1E26),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF232530),
    textLight: Color(0xFF1C1E26),
    textDark: Color(0xFFCBCED0),
  ),
  ThemeConfig(
    displayName: 'Palenight',
    primaryLight: Color(0xFF82AAFF),
    primaryDark: Color(0xFF82AAFF),
    secondaryLight: Color(0xFFC792EA),
    secondaryDark: Color(0xFFC792EA),
    tertiaryLight: Color(0xFFF78C6C),
    tertiaryDark: Color(0xFFF78C6C),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF292D3E),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF3A3F58),
    textLight: Color(0xFF292D3E),
    textDark: Color(0xFFA6ACCD),
  ),
  ThemeConfig(
    displayName: 'Cyberpunk',
    primaryLight: Color(0xFF00F5D4),
    primaryDark: Color(0xFF00F5D4),
    secondaryLight: Color(0xFFFF00FF),
    secondaryDark: Color(0xFFFF00FF),
    tertiaryLight: Color(0xFFFF6600),
    tertiaryDark: Color(0xFFFF6600),
    backgroundLight: Color(0xFFF0F0F0),
    backgroundDark: Color(0xFF0A0A0A),
    surfaceLight: Color(0xFFE0E0E0),
    surfaceDark: Color(0xFF141414),
    textLight: Color(0xFF0A0A0A),
    textDark: Color(0xFFF5F5F5),
  ),
  ThemeConfig(
    displayName: 'AMOLED Black',
    primaryLight: Color(0xFF00E5FF),
    primaryDark: Color(0xFF00E5FF),
    secondaryLight: Color(0xFF00B8D4),
    secondaryDark: Color(0xFF00B8D4),
    tertiaryLight: Color(0xFF18FFFF),
    tertiaryDark: Color(0xFF18FFFF),
    backgroundLight: Color(0xFFFAFAFA),
    backgroundDark: Color(0xFF000000),
    surfaceLight: Color(0xFFF0F0F0),
    surfaceDark: Color(0xFF121212),
    textLight: Color(0xFF000000),
    textDark: Color(0xFFFFFFFF),
  ),
];

class _ThemeDataCache {
  final ThemeConfig config;
  final Brightness brightness;
  final bool amoled;
  final ColorScheme? dynamicScheme;
  final ThemeData themeData;

  const _ThemeDataCache({
    required this.config,
    required this.brightness,
    required this.amoled,
    this.dynamicScheme,
    required this.themeData,
  });
}

class AppTheme {
  static _ThemeDataCache? _lastCache;

  static ThemeData createTheme({
    required ThemeConfig config,
    required Brightness brightness,
    ColorScheme? dynamicScheme,
    bool amoled = false,
  }) {
    if (_lastCache != null &&
        _lastCache!.config == config &&
        _lastCache!.brightness == brightness &&
        _lastCache!.amoled == amoled &&
        _lastCache!.dynamicScheme == dynamicScheme) {
      return _lastCache!.themeData;
    }

    final colorScheme = config.isDynamic && dynamicScheme != null
        ? (brightness == Brightness.light
            ? dynamicScheme
            : amoled
                ? dynamicScheme.copyWith(
                    background: Colors.black,
                    surface: Colors.black,
                  )
                : dynamicScheme)
        : brightness == Brightness.light
            ? config.getLightColorScheme()
            : amoled
                ? config.getAmoledColorScheme()
                : config.getDarkColorScheme();

    final isDark = brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
    );

    final result = ThemeData(
      useMaterial3: false,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.background,
      colorScheme: colorScheme,
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surface,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.12),
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        secondarySelectedColor: colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.primary),
        checkmarkColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide.none,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primary.withValues(alpha: 0.24),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.onSurface,
        contentTextStyle: TextStyle(color: colorScheme.surface),
        actionTextColor: colorScheme.primary,
      ),
      splashColor: colorScheme.primary.withValues(alpha: 0.1),
      hoverColor: colorScheme.primary.withValues(alpha: 0.04),
      highlightColor: colorScheme.primary.withValues(alpha: 0.05),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: colorScheme.primary,
      ),
      dividerColor: colorScheme.outlineVariant,
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: colorScheme.outlineVariant,
      ),
    );

    _lastCache = _ThemeDataCache(
      config: config,
      brightness: brightness,
      amoled: amoled,
      dynamicScheme: dynamicScheme,
      themeData: result,
    );

    return result;
  }
}
