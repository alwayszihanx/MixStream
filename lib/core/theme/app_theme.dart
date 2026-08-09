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
      surface: surfaceLight,
      onSurface: textLight,
      surfaceContainerHighest: surfaceLight.darken(0.05),
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
      surface: surfaceDark,
      onSurface: textDark,
      surfaceContainerHighest: surfaceDark.lighten(0.08),
      onSurfaceVariant: textDark.withValues(alpha: 0.65),
      outline: secondaryDark.withValues(alpha: 0.5).compositeOver(const Color(0xFF938F99)),
      outlineVariant: primaryDark.withValues(alpha: 0.22).compositeOver(const Color(0xFF49454F)),
      inverseSurface: backgroundLight,
      onInverseSurface: const Color(0xFF313033),
      inversePrimary: primaryLight,
    );
  }

  ColorScheme getAmoledColorScheme() => getDarkColorScheme().copyWith(
    surface: Colors.black,
    surfaceContainerHighest: primaryDark.withValues(alpha: 0.08).compositeOver(const Color(0xFF1A1A1A)),
    onSurface: textDark,
  );
}

const List<ThemeConfig> allThemes = [
  // 1. Midnight Violet - Deep purple accent
  ThemeConfig(
    displayName: 'Midnight Violet',
    primaryLight: Color(0xFF6C63FF),
    primaryDark: Color(0xFF9D97FF),
    secondaryLight: Color(0xFF8B7FFF),
    secondaryDark: Color(0xFFB3ADFF),
    tertiaryLight: Color(0xFF4A42D9),
    tertiaryDark: Color(0xFFC4BFFF),
    backgroundLight: Color(0xFFF5F4FF),
    backgroundDark: Color(0xFF0D0B1E),
    surfaceLight: Color(0xFFEDEBFF),
    surfaceDark: Color(0xFF1A1730),
    textLight: Color(0xFF1A1440),
    textDark: Color(0xFFE8E5FF),
  ),
  // 2. Crimson - Rich red accent
  ThemeConfig(
    displayName: 'Crimson',
    primaryLight: Color(0xFFFF3D71),
    primaryDark: Color(0xFFFF6B8F),
    secondaryLight: Color(0xFFFF5C8A),
    secondaryDark: Color(0xFFFF8AAE),
    tertiaryLight: Color(0xFFD92E5A),
    tertiaryDark: Color(0xFFFFA8C4),
    backgroundLight: Color(0xFFFFF5F5),
    backgroundDark: Color(0xFF1A0A0A),
    surfaceLight: Color(0xFFFFE8E8),
    surfaceDark: Color(0xFF2D1515),
    textLight: Color(0xFF3A0A15),
    textDark: Color(0xFFFFE5E5),
  ),
  // 3. Emerald - Deep green accent
  ThemeConfig(
    displayName: 'Emerald',
    primaryLight: Color(0xFF00D68F),
    primaryDark: Color(0xFF33E0A8),
    secondaryLight: Color(0xFF00BF7F),
    secondaryDark: Color(0xFF66EABF),
    tertiaryLight: Color(0xFF00A870),
    tertiaryDark: Color(0xFF99F0D4),
    backgroundLight: Color(0xFFF5FFF8),
    backgroundDark: Color(0xFF0A1A12),
    surfaceLight: Color(0xFFE5FFF0),
    surfaceDark: Color(0xFF152D20),
    textLight: Color(0xFF0A2A18),
    textDark: Color(0xFFE0FFE8),
  ),
  // 4. Cerulean - Ocean blue accent
  ThemeConfig(
    displayName: 'Cerulean',
    primaryLight: Color(0xFF0095FF),
    primaryDark: Color(0xFF33A8FF),
    secondaryLight: Color(0xFF0080E0),
    secondaryDark: Color(0xFF66BFFF),
    tertiaryLight: Color(0xFF006BBF),
    tertiaryDark: Color(0xFF99D4FF),
    backgroundLight: Color(0xFFF5F8FF),
    backgroundDark: Color(0xFF0A1428),
    surfaceLight: Color(0xFFE5EEFF),
    surfaceDark: Color(0xFF152040),
    textLight: Color(0xFF0A1A3A),
    textDark: Color(0xFFE0EEFF),
  ),
  // 5. Amber - Warm gold accent
  ThemeConfig(
    displayName: 'Amber',
    primaryLight: Color(0xFFFFAA00),
    primaryDark: Color(0xFFFFBB33),
    secondaryLight: Color(0xFFE09500),
    secondaryDark: Color(0xFFFFCC66),
    tertiaryLight: Color(0xFFBF8000),
    tertiaryDark: Color(0xFFFFDD99),
    backgroundLight: Color(0xFFFFF8F0),
    backgroundDark: Color(0xFF1A1408),
    surfaceLight: Color(0xFFFFF0D8),
    surfaceDark: Color(0xFF2D2515),
    textLight: Color(0xFF3A2808),
    textDark: Color(0xFFFFF0D0),
  ),
  // 6. Rose - Soft pink accent
  ThemeConfig(
    displayName: 'Rose',
    primaryLight: Color(0xFFFF6B9D),
    primaryDark: Color(0xFFFF8EB5),
    secondaryLight: Color(0xFFE05A88),
    secondaryDark: Color(0xFFFFA8C4),
    tertiaryLight: Color(0xFFBF4A75),
    tertiaryDark: Color(0xFFFFC0D8),
    backgroundLight: Color(0xFFFFF5F8),
    backgroundDark: Color(0xFF1A0A12),
    surfaceLight: Color(0xFFFFE5EE),
    surfaceDark: Color(0xFF2D1520),
    textLight: Color(0xFF3A0A20),
    textDark: Color(0xFFFFE5F0),
  ),
  // 7. Carbon - Pure gray accent
  ThemeConfig(
    displayName: 'Carbon',
    primaryLight: Color(0xFF9E9E9E),
    primaryDark: Color(0xFFBDBDBD),
    secondaryLight: Color(0xFF888888),
    secondaryDark: Color(0xFFADADAD),
    tertiaryLight: Color(0xFF757575),
    tertiaryDark: Color(0xFFD0D0D0),
    backgroundLight: Color(0xFFF5F5F5),
    backgroundDark: Color(0xFF0A0A0A),
    surfaceLight: Color(0xFFE8E8E8),
    surfaceDark: Color(0xFF1A1A1A),
    textLight: Color(0xFF1A1A1A),
    textDark: Color(0xFFEEEEEE),
  ),
  // 8. Cyan - Electric cyan accent
  ThemeConfig(
    displayName: 'Cyan',
    primaryLight: Color(0xFF00E5FF),
    primaryDark: Color(0xFF33EBFF),
    secondaryLight: Color(0xFF00CCE0),
    secondaryDark: Color(0xFF66F0FF),
    tertiaryLight: Color(0xFF00B3CC),
    tertiaryDark: Color(0xFF99F5FF),
    backgroundLight: Color(0xFFF5FFFF),
    backgroundDark: Color(0xFF0A1A1A),
    surfaceLight: Color(0xFFE5FFFF),
    surfaceDark: Color(0xFF152D2D),
    textLight: Color(0xFF0A2A2A),
    textDark: Color(0xFFE0FFFF),
  ),
  // 9. Sunset - Warm orange accent
  ThemeConfig(
    displayName: 'Sunset',
    primaryLight: Color(0xFFFF6D00),
    primaryDark: Color(0xFFFF8533),
    secondaryLight: Color(0xFFE06000),
    secondaryDark: Color(0xFFFFA066),
    tertiaryLight: Color(0xFFBF5200),
    tertiaryDark: Color(0xFFFFB899),
    backgroundLight: Color(0xFFFFF5F0),
    backgroundDark: Color(0xFF1A0D05),
    surfaceLight: Color(0xFFFFE8DD),
    surfaceDark: Color(0xFF2D1A0D),
    textLight: Color(0xFF3A1A08),
    textDark: Color(0xFFFFE8DD),
  ),
  // 10. Lavender - Soft purple accent
  ThemeConfig(
    displayName: 'Lavender',
    primaryLight: Color(0xFFB388FF),
    primaryDark: Color(0xFFC9A8FF),
    secondaryLight: Color(0xFF9E70E0),
    secondaryDark: Color(0xFFDBBFFF),
    tertiaryLight: Color(0xFF8858CC),
    tertiaryDark: Color(0xFFE8D5FF),
    backgroundLight: Color(0xFFF8F5FF),
    backgroundDark: Color(0xFF120D1A),
    surfaceLight: Color(0xFFF0E8FF),
    surfaceDark: Color(0xFF20152D),
    textLight: Color(0xFF200A30),
    textDark: Color(0xFFF0E8FF),
  ),
  // 11. Coral Reef - Warm coral accent
  ThemeConfig(
    displayName: 'Coral Reef',
    primaryLight: Color(0xFFFF6B6B),
    primaryDark: Color(0xFFFF8A8A),
    secondaryLight: Color(0xFFE05555),
    secondaryDark: Color(0xFFFFA8A8),
    tertiaryLight: Color(0xFFD94545),
    tertiaryDark: Color(0xFFFFC0C0),
    backgroundLight: Color(0xFFFFF5F5),
    backgroundDark: Color(0xFF1A0D0D),
    surfaceLight: Color(0xFFFFE8E8),
    surfaceDark: Color(0xFF2D1A1A),
    textLight: Color(0xFF3A1515),
    textDark: Color(0xFFFFE5E5),
  ),
  // 12. Deep Space - Cosmic indigo accent
  ThemeConfig(
    displayName: 'Deep Space',
    primaryLight: Color(0xFF5C6BC0),
    primaryDark: Color(0xFF7986CB),
    secondaryLight: Color(0xFF4A5AA8),
    secondaryDark: Color(0xFF9FA8DA),
    tertiaryLight: Color(0xFF3F4E96),
    tertiaryDark: Color(0xFFB0BEC5),
    backgroundLight: Color(0xFFF0F1FA),
    backgroundDark: Color(0xFF0A0A1A),
    surfaceLight: Color(0xFFE0E2F5),
    surfaceDark: Color(0xFF15152D),
    textLight: Color(0xFF101030),
    textDark: Color(0xFFE0E2F5),
  ),
  // 13. Tropical - Vibrant teal accent
  ThemeConfig(
    displayName: 'Tropical',
    primaryLight: Color(0xFF26C6DA),
    primaryDark: Color(0xFF4DD0E1),
    secondaryLight: Color(0xFF00ACC1),
    secondaryDark: Color(0xFF80DEEA),
    tertiaryLight: Color(0xFF0097A7),
    tertiaryDark: Color(0xFFB2EBF2),
    backgroundLight: Color(0xFFF0FBFD),
    backgroundDark: Color(0xFF0A1A1D),
    surfaceLight: Color(0xFFE0F5F8),
    surfaceDark: Color(0xFF152D30),
    textLight: Color(0xFF0A2A2D),
    textDark: Color(0xFFE0F5F8),
  ),
  // 14. Royal - Rich gold on deep purple bg
  ThemeConfig(
    displayName: 'Royal',
    primaryLight: Color(0xFFFFD700),
    primaryDark: Color(0xFFFFE033),
    secondaryLight: Color(0xFFE0C000),
    secondaryDark: Color(0xFFFFEC66),
    tertiaryLight: Color(0xFFBFA800),
    tertiaryDark: Color(0xFFFFF599),
    backgroundLight: Color(0xFFFFF8F0),
    backgroundDark: Color(0xFF1A1028),
    surfaceLight: Color(0xFFFFF0D8),
    surfaceDark: Color(0xFF2D1A40),
    textLight: Color(0xFF3A1A08),
    textDark: Color(0xFFFFF0D0),
  ),
  // 15. Sakura - Cherry blossom pink accent
  ThemeConfig(
    displayName: 'Sakura',
    primaryLight: Color(0xFFFF8A9E),
    primaryDark: Color(0xFFFFA8B8),
    secondaryLight: Color(0xFFE07088),
    secondaryDark: Color(0xFFFFC0D0),
    tertiaryLight: Color(0xFFD96078),
    tertiaryDark: Color(0xFFFFD8E5),
    backgroundLight: Color(0xFFFFF5F8),
    backgroundDark: Color(0xFF1A0D12),
    surfaceLight: Color(0xFFFFE8F0),
    surfaceDark: Color(0xFF2D1A22),
    textLight: Color(0xFF3A1018),
    textDark: Color(0xFFFFE5EE),
  ),
  // 16. Matrix - Hacker green on pure black
  ThemeConfig(
    displayName: 'Matrix',
    primaryLight: Color(0xFF00FF41),
    primaryDark: Color(0xFF33FF66),
    secondaryLight: Color(0xFF00CC33),
    secondaryDark: Color(0xFF66FF88),
    tertiaryLight: Color(0xFF00AA28),
    tertiaryDark: Color(0xFF99FFBB),
    backgroundLight: Color(0xFFF0FFF0),
    backgroundDark: Color(0xFF000000),
    surfaceLight: Color(0xFFE0FFE0),
    surfaceDark: Color(0xFF0A0A0A),
    textLight: Color(0xFF0A2A10),
    textDark: Color(0xFF00FF41),
  ),
  // 17. Ocean Deep - Dark navy with cyan accent
  ThemeConfig(
    displayName: 'Ocean Deep',
    primaryLight: Color(0xFF00BCD4),
    primaryDark: Color(0xFF26C6DA),
    secondaryLight: Color(0xFF0097A7),
    secondaryDark: Color(0xFF4DD0E1),
    tertiaryLight: Color(0xFF00838F),
    tertiaryDark: Color(0xFF80DEEA),
    backgroundLight: Color(0xFFF0F8FF),
    backgroundDark: Color(0xFF0A0D1A),
    surfaceLight: Color(0xFFE0F0FF),
    surfaceDark: Color(0xFF15202D),
    textLight: Color(0xFF0A1530),
    textDark: Color(0xFFE0F0FF),
  ),
  // 18. Flame - Fiery primary
  ThemeConfig(
    displayName: 'Flame',
    primaryLight: Color(0xFFFF5722),
    primaryDark: Color(0xFFFF7043),
    secondaryLight: Color(0xFFE04510),
    secondaryDark: Color(0xFFFF8A65),
    tertiaryLight: Color(0xFFBF3A00),
    tertiaryDark: Color(0xFFFFAB91),
    backgroundLight: Color(0xFFFFF5F0),
    backgroundDark: Color(0xFF1A0D05),
    surfaceLight: Color(0xFFFFE8DD),
    surfaceDark: Color(0xFF2D1A0D),
    textLight: Color(0xFF3A1A08),
    textDark: Color(0xFFFFE8DD),
  ),
  // 19. Nord - Arctic blue with frosty bg
  ThemeConfig(
    displayName: 'Nord',
    primaryLight: Color(0xFF88C0D0),
    primaryDark: Color(0xFFA3D4DE),
    secondaryLight: Color(0xFF81A1C1),
    secondaryDark: Color(0xFFB4C8DC),
    tertiaryLight: Color(0xFF5E81AC),
    tertiaryDark: Color(0xFFD8DEE9),
    backgroundLight: Color(0xFFF5F8FA),
    backgroundDark: Color(0xFF0D1117),
    surfaceLight: Color(0xFFE5ECF0),
    surfaceDark: Color(0xFF1A2028),
    textLight: Color(0xFF1A2A35),
    textDark: Color(0xFFE5ECF0),
  ),
  // 20. Dracula - Purple on dark bg
  ThemeConfig(
    displayName: 'Dracula',
    primaryLight: Color(0xFFBD93F9),
    primaryDark: Color(0xFFD0B5FF),
    secondaryLight: Color(0xFFFF79C6),
    secondaryDark: Color(0xFFFF92D0),
    tertiaryLight: Color(0xFF8BE9FD),
    tertiaryDark: Color(0xFFFFB8E0),
    backgroundLight: Color(0xFFF8F5FF),
    backgroundDark: Color(0xFF282A36),
    surfaceLight: Color(0xFFF0E8FF),
    surfaceDark: Color(0xFF3A3C4A),
    textLight: Color(0xFF200A30),
    textDark: Color(0xFFF8F8F2),
  ),
  // 21. One Dark - VS Code dark blue on dark bg
  ThemeConfig(
    displayName: 'One Dark',
    primaryLight: Color(0xFF61AFEF),
    primaryDark: Color(0xFF82C4FF),
    secondaryLight: Color(0xFFC678DD),
    secondaryDark: Color(0xFFD9A0EC),
    tertiaryLight: Color(0xFF98C379),
    tertiaryDark: Color(0xFFB8E0A0),
    backgroundLight: Color(0xFFF5F5F5),
    backgroundDark: Color(0xFF282C34),
    surfaceLight: Color(0xFFE8E8E8),
    surfaceDark: Color(0xFF3A3E48),
    textLight: Color(0xFF1A1A1A),
    textDark: Color(0xFFABB2BF),
  ),
  // 22. Gruvbox - Retro orange on dark
  ThemeConfig(
    displayName: 'Gruvbox',
    primaryLight: Color(0xFFFE8019),
    primaryDark: Color(0xFFFFAA55),
    secondaryLight: Color(0xFFB8BB26),
    secondaryDark: Color(0xFFD4E050),
    tertiaryLight: Color(0xFF83A598),
    tertiaryDark: Color(0xFFA0C4B8),
    backgroundLight: Color(0xFFFFF8F0),
    backgroundDark: Color(0xFF282828),
    surfaceLight: Color(0xFFFFF0D8),
    surfaceDark: Color(0xFF3A3A3A),
    textLight: Color(0xFF3A2808),
    textDark: Color(0xFFEBDBB2),
  ),
  // 23. Solarized - Blue on dark
  ThemeConfig(
    displayName: 'Solarized',
    primaryLight: Color(0xFF268BD2),
    primaryDark: Color(0xFF4AA0E0),
    secondaryLight: Color(0xFF2AA198),
    secondaryDark: Color(0xFF55C4B8),
    tertiaryLight: Color(0xFF6C71C4),
    tertiaryDark: Color(0xFF9E9ED0),
    backgroundLight: Color(0xFFFDF6E3),
    backgroundDark: Color(0xFF002B36),
    surfaceLight: Color(0xFFF0E8D0),
    surfaceDark: Color(0xFF073642),
    textLight: Color(0xFF002B36),
    textDark: Color(0xFFFDF6E3),
  ),
  // 24. Tokyo Night - Purple-blue on dark
  ThemeConfig(
    displayName: 'Tokyo Night',
    primaryLight: Color(0xFF7AA2F7),
    primaryDark: Color(0xFF9AB8FF),
    secondaryLight: Color(0xFFBB9AF7),
    secondaryDark: Color(0xFFD0B8FF),
    tertiaryLight: Color(0xFF73DACA),
    tertiaryDark: Color(0xFFA0E8D8),
    backgroundLight: Color(0xFFF5F5FF),
    backgroundDark: Color(0xFF1A1B26),
    surfaceLight: Color(0xFFE8E8F5),
    surfaceDark: Color(0xFF24283B),
    textLight: Color(0xFF1A1A30),
    textDark: Color(0xFFC0CAF5),
  ),
  // 25. Catppuccin - Mauve on dark
  ThemeConfig(
    displayName: 'Catppuccin',
    primaryLight: Color(0xFFCBA6F7),
    primaryDark: Color(0xFFDDBDF7),
    secondaryLight: Color(0xFFF5C2E7),
    secondaryDark: Color(0xFFFFD0EE),
    tertiaryLight: Color(0xFF94E2D5),
    tertiaryDark: Color(0xFFB8F0E8),
    backgroundLight: Color(0xFFF8F5FF),
    backgroundDark: Color(0xFF1E1E2E),
    surfaceLight: Color(0xFFF0E8FF),
    surfaceDark: Color(0xFF313244),
    textLight: Color(0xFF200A30),
    textDark: Color(0xFFCDD6F4),
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
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
      ),
    );

    final result = ThemeData(
      useMaterial3: false,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      colorScheme: colorScheme,
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surface,
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurface.withValues(alpha: 0.2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.primary.withValues(alpha: 0.05),
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.12),
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        secondarySelectedColor: colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.primary),
        checkmarkColor: colorScheme.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: const ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.onSurface,
        contentTextStyle: TextStyle(color: colorScheme.surface),
        actionTextColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        behavior: SnackBarBehavior.floating,
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
