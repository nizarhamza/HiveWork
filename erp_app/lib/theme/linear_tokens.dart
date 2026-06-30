import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Dark palette ──────────────────────────────────────────────────────────────

abstract final class LinearColors {
  // Backgrounds
  static const Color pageBg        = Color(0xFF0D0D0D);
  static const Color surfaceBase   = Color(0xFF131315);
  static const Color surfaceRaised = Color(0xFF1C1C1E);

  // Text
  static const Color textPrimary   = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted     = Color(0xFF71717A);

  // Borders (semi-transparent white)
  static const Color borderSubtle  = Color(0x12FFFFFF); //  7 %
  static const Color borderBase    = Color(0x1CFFFFFF); // 11 %

  // Overlays
  static const Color overlay       = Color(0x0AFFFFFF); //  4 %
  static const Color overlayActive = Color(0x12FFFFFF); //  7 %

  // Accent
  static const Color accent        = Color(0xFF5E6AD2);
  static const Color accentHover   = Color(0xFF6872D6);

  // Status — same in both themes
  static const Color success = Color(0xFF4CAF72);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger  = Color(0xFFC2554D);
}

// ── Light palette ─────────────────────────────────────────────────────────────

abstract final class LinearLightColors {
  static const Color pageBg        = Color(0xFFEAEAEC);
  static const Color surfaceBase   = Color(0xFFF4F4F6);
  static const Color surfaceRaised = Color(0xFFE4E4E6);

  static const Color textPrimary   = Color(0xFF0F0F10);
  static const Color textSecondary = Color(0xFF4B4B57);
  static const Color textMuted     = Color(0xFF8B8B97);

  // Borders (semi-transparent black)
  static const Color borderSubtle  = Color(0x14000000); //  8 %
  static const Color borderBase    = Color(0x20000000); // 13 %

  static const Color overlay       = Color(0x09000000); //  3.5 %
  static const Color overlayActive = Color(0x14000000); //  8 %
}

// ── Spacing ───────────────────────────────────────────────────────────────────

abstract final class LinearSpacing {
  static const double xxs  = 2;
  static const double xs   = 4;
  static const double sm   = 8;
  static const double base = 12;
  static const double md   = 16;
  static const double lg   = 20;
  static const double xl   = 24;
}

// ── Radii ─────────────────────────────────────────────────────────────────────

abstract final class LinearRadii {
  static const double xs   = 3;
  static const double sm   = 4;
  static const double md   = 6;
  static const double lg   = 8;
  static const double pill = 999;
}

// ── Shell dimensional tokens ──────────────────────────────────────────────────

class LinearTokens {
  const LinearTokens();
  double get sidebarWidth      => 232;
  double get headerHeight      => 44;
  double get rowHeightDefault  => 30;
  double get navRowHeight      => 30;
  double get iconSizeMd        => 16;
}

// ── ThemeExtension — all switchable brand tokens ──────────────────────────────

@immutable
class LinearExt extends ThemeExtension<LinearExt> {
  const LinearExt({
    required this.tokens,
    required this.pageBg,
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.borderBase,
    required this.overlay,
    required this.overlayActive,
    required this.success,
    required this.warning,
  });

  // ── Named variants ────────────────────────────────────────────────────────

  static const dark = LinearExt(
    tokens:        LinearTokens(),
    pageBg:        LinearColors.pageBg,
    surfaceBase:   LinearColors.surfaceBase,
    surfaceRaised: LinearColors.surfaceRaised,
    textPrimary:   LinearColors.textPrimary,
    textSecondary: LinearColors.textSecondary,
    textMuted:     LinearColors.textMuted,
    borderSubtle:  LinearColors.borderSubtle,
    borderBase:    LinearColors.borderBase,
    overlay:       LinearColors.overlay,
    overlayActive: LinearColors.overlayActive,
    success:       LinearColors.success,
    warning:       LinearColors.warning,
  );

  static const light = LinearExt(
    tokens:        LinearTokens(),
    pageBg:        LinearLightColors.pageBg,
    surfaceBase:   LinearLightColors.surfaceBase,
    surfaceRaised: LinearLightColors.surfaceRaised,
    textPrimary:   LinearLightColors.textPrimary,
    textSecondary: LinearLightColors.textSecondary,
    textMuted:     LinearLightColors.textMuted,
    borderSubtle:  LinearLightColors.borderSubtle,
    borderBase:    LinearLightColors.borderBase,
    overlay:       LinearLightColors.overlay,
    overlayActive: LinearLightColors.overlayActive,
    success:       LinearColors.success,
    warning:       LinearColors.warning,
  );

  // ── Fields ────────────────────────────────────────────────────────────────

  final LinearTokens tokens;
  final Color pageBg;
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color borderBase;
  final Color overlay;
  final Color overlayActive;
  final Color success;
  final Color warning;

  @override
  LinearExt copyWith({
    LinearTokens? tokens,
    Color? pageBg, Color? surfaceBase, Color? surfaceRaised,
    Color? textPrimary, Color? textSecondary, Color? textMuted,
    Color? borderSubtle, Color? borderBase,
    Color? overlay, Color? overlayActive,
    Color? success, Color? warning,
  }) => LinearExt(
    tokens:        tokens        ?? this.tokens,
    pageBg:        pageBg        ?? this.pageBg,
    surfaceBase:   surfaceBase   ?? this.surfaceBase,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    textPrimary:   textPrimary   ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted:     textMuted     ?? this.textMuted,
    borderSubtle:  borderSubtle  ?? this.borderSubtle,
    borderBase:    borderBase    ?? this.borderBase,
    overlay:       overlay       ?? this.overlay,
    overlayActive: overlayActive ?? this.overlayActive,
    success:       success       ?? this.success,
    warning:       warning       ?? this.warning,
  );

  @override
  LinearExt lerp(ThemeExtension<LinearExt>? other, double t) {
    if (other is! LinearExt) return this;
    return LinearExt(
      tokens:        tokens,
      pageBg:        Color.lerp(pageBg,        other.pageBg,        t)!,
      surfaceBase:   Color.lerp(surfaceBase,   other.surfaceBase,   t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
      borderSubtle:  Color.lerp(borderSubtle,  other.borderSubtle,  t)!,
      borderBase:    Color.lerp(borderBase,    other.borderBase,    t)!,
      overlay:       Color.lerp(overlay,       other.overlay,       t)!,
      overlayActive: Color.lerp(overlayActive, other.overlayActive, t)!,
      success:       Color.lerp(success,       other.success,       t)!,
      warning:       Color.lerp(warning,       other.warning,       t)!,
    );
  }
}

// ── Context helpers ───────────────────────────────────────────────────────────

extension LinearContext on BuildContext {
  LinearTokens get linearTokens =>
      Theme.of(this).extension<LinearExt>()?.tokens ?? const LinearTokens();

  LinearExt get linearExt =>
      Theme.of(this).extension<LinearExt>() ?? LinearExt.dark;

  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme   get text   => Theme.of(this).textTheme;
}

// ── ColorSchemes ──────────────────────────────────────────────────────────────

ColorScheme _buildDarkScheme({
  Color accent = LinearColors.accent,
  Color pageBg = LinearColors.pageBg,
}) =>
    ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
      primary:                 accent,
      onPrimary:               Colors.white,
      surface:                 pageBg,
      onSurface:               LinearColors.textPrimary,
      onSurfaceVariant:        LinearColors.textSecondary,
      surfaceContainer:        LinearColors.surfaceBase,
      surfaceContainerHigh:    LinearColors.surfaceRaised,
      surfaceContainerHighest: LinearColors.surfaceRaised,
      outline:                 LinearColors.borderBase,
      outlineVariant:          LinearColors.borderSubtle,
      error:                   LinearColors.danger,
      onError:                 Colors.white,
      shadow:                  Colors.black,
      scrim:                   Colors.black,
    );

ColorScheme _buildLightScheme({
  Color accent = LinearColors.accent,
  Color pageBg = LinearLightColors.pageBg,
}) =>
    ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light).copyWith(
      primary:                 accent,
      onPrimary:               Colors.white,
      surface:                 pageBg,
      onSurface:               LinearLightColors.textPrimary,
      onSurfaceVariant:        LinearLightColors.textSecondary,
      surfaceContainer:        LinearLightColors.surfaceBase,
      surfaceContainerHigh:    LinearLightColors.surfaceRaised,
      surfaceContainerHighest: LinearLightColors.surfaceRaised,
      outline:                 LinearLightColors.borderBase,
      outlineVariant:          LinearLightColors.borderSubtle,
      error:                   LinearColors.danger,
      onError:                 Colors.white,
      shadow:                  Colors.black,
      scrim:                   Colors.black,
    );

// ── TextTheme ─────────────────────────────────────────────────────────────────

TextTheme _applyGoogleFont(String family, TextTheme base) {
  switch (family) {
    case 'DM Sans':           return GoogleFonts.dmSansTextTheme(base);
    case 'Plus Jakarta Sans': return GoogleFonts.plusJakartaSansTextTheme(base);
    case 'IBM Plex Sans':     return GoogleFonts.ibmPlexSansTextTheme(base);
    case 'Roboto':            return GoogleFonts.robotoTextTheme(base);
    default:                  return GoogleFonts.interTextTheme(base);
  }
}

TextTheme _buildTextTheme(LinearExt e, {String fontFamily = 'Inter', double scale = 1.0}) {
  final s = scale;
  final base = TextTheme(
    displayLarge:   TextStyle(fontSize: 48 * s, fontWeight: FontWeight.w700, color: e.textPrimary,   letterSpacing: -0.5),
    displayMedium:  TextStyle(fontSize: 36 * s, fontWeight: FontWeight.w600, color: e.textPrimary,   letterSpacing: -0.3),
    displaySmall:   TextStyle(fontSize: 28 * s, fontWeight: FontWeight.w600, color: e.textPrimary,   letterSpacing: -0.2),
    headlineLarge:  TextStyle(fontSize: 24 * s, fontWeight: FontWeight.w600, color: e.textPrimary),
    headlineMedium: TextStyle(fontSize: 20 * s, fontWeight: FontWeight.w600, color: e.textPrimary),
    headlineSmall:  TextStyle(fontSize: 17 * s, fontWeight: FontWeight.w600, color: e.textPrimary),
    titleLarge:     TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w600, color: e.textPrimary),
    titleMedium:    TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w600, color: e.textPrimary),
    titleSmall:     TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w500, color: e.textPrimary),
    bodyLarge:      TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w400, color: e.textSecondary),
    bodyMedium:     TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w400, color: e.textSecondary),
    bodySmall:      TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w400, color: e.textSecondary),
    labelLarge:     TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w500, color: e.textSecondary),
    labelMedium:    TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w500, color: e.textSecondary),
    labelSmall:     TextStyle(fontSize: 10 * s, fontWeight: FontWeight.w500, color: e.textMuted),
  );
  return _applyGoogleFont(fontFamily, base);
}

// ── Internal shared theme builder ─────────────────────────────────────────────

ThemeData _buildTheme({
  required ColorScheme scheme,
  required LinearExt ext,
  required Color accent,
  String fontFamily = 'Inter',
  double fontScale  = 1.0,
}) {
  return ThemeData(
    useMaterial3:            true,
    colorScheme:             scheme,
    scaffoldBackgroundColor: ext.pageBg,
    fontFamily:              fontFamily,
    extensions:              [ext],
    textTheme:               _buildTextTheme(ext, fontFamily: fontFamily, scale: fontScale),

    dividerTheme: DividerThemeData(
      color: ext.borderSubtle, thickness: 1, space: 1,
    ),

    // ── Inputs ──────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ext.surfaceBase,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.base, vertical: LinearSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        borderSide: BorderSide(color: ext.borderBase),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        borderSide: BorderSide(color: ext.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        borderSide: const BorderSide(color: LinearColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        borderSide: const BorderSide(color: LinearColors.danger, width: 1.5),
      ),
      hintStyle: TextStyle(fontSize: 13, color: ext.textMuted),
      labelStyle: TextStyle(fontSize: 13, color: ext.textSecondary),
    ),

    // ── Buttons ─────────────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadii.md)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ext.textPrimary,
        side: BorderSide(color: ext.borderBase),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadii.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ext.textSecondary,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm, vertical: 5),
        minimumSize: const Size(0, 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadii.md)),
      ),
    ),

    // ── Controls ────────────────────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? accent : Colors.transparent),
      side: BorderSide(color: ext.borderBase, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadii.xs)),
      overlayColor: WidgetStatePropertyAll(ext.overlayActive),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? accent : ext.borderBase),
      overlayColor: WidgetStatePropertyAll(ext.overlayActive),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : ext.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? accent : ext.surfaceBase),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.transparent : ext.borderBase),
      overlayColor: WidgetStatePropertyAll(ext.overlayActive),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor:         ext.surfaceBase,
        selectedBackgroundColor: ext.surfaceRaised,
        foregroundColor:         ext.textSecondary,
        selectedForegroundColor: ext.textPrimary,
        side: BorderSide(color: ext.borderSubtle),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadii.md)),
      ),
    ),

    // ── Overlays ────────────────────────────────────────────────────────────
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: ext.surfaceRaised,
        borderRadius: BorderRadius.circular(LinearRadii.sm),
        border: Border.all(color: ext.borderSubtle),
      ),
      textStyle: TextStyle(fontSize: 12, color: ext.textSecondary),
      waitDuration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.sm, vertical: LinearSpacing.xs,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: ext.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        side: BorderSide(color: ext.borderSubtle),
      ),
      textStyle: TextStyle(fontSize: 13, color: ext.textSecondary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ext.surfaceRaised,
      contentTextStyle: TextStyle(fontSize: 13, color: ext.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadii.md),
        side: BorderSide(color: ext.borderSubtle),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ext.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadii.lg),
        side: BorderSide(color: ext.borderSubtle),
      ),
      titleTextStyle: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: ext.textPrimary,
      ),
      contentTextStyle: TextStyle(
        fontSize: 13, color: ext.textSecondary,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor:  WidgetStatePropertyAll(ext.surfaceRaised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation:        const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LinearRadii.md),
          side: BorderSide(color: ext.borderSubtle),
        )),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: LinearSpacing.xs),
        ),
      ),
    ),
  );
}

// ── Public API ────────────────────────────────────────────────────────────────

ThemeData buildLinearDarkTheme({
  Color  accent       = LinearColors.accent,
  Color  pageBg       = LinearColors.pageBg,
  Color  surfaceBase  = LinearColors.surfaceBase,
  Color  surfaceRaised = LinearColors.surfaceRaised,
  String fontFamily   = 'Inter',
  double fontScale    = 1.0,
}) {
  final ext = LinearExt.dark.copyWith(
    pageBg:        pageBg,
    surfaceBase:   surfaceBase,
    surfaceRaised: surfaceRaised,
  );
  return _buildTheme(
    scheme:     _buildDarkScheme(accent: accent, pageBg: pageBg),
    ext:        ext,
    accent:     accent,
    fontFamily: fontFamily,
    fontScale:  fontScale,
  );
}

ThemeData buildLinearLightTheme({
  Color  accent       = LinearColors.accent,
  Color  pageBg       = LinearLightColors.pageBg,
  Color  surfaceBase  = LinearLightColors.surfaceBase,
  Color  surfaceRaised = LinearLightColors.surfaceRaised,
  String fontFamily   = 'Inter',
  double fontScale    = 1.0,
}) {
  final ext = LinearExt.light.copyWith(
    pageBg:        pageBg,
    surfaceBase:   surfaceBase,
    surfaceRaised: surfaceRaised,
  );
  return _buildTheme(
    scheme:     _buildLightScheme(accent: accent, pageBg: pageBg),
    ext:        ext,
    accent:     accent,
    fontFamily: fontFamily,
    fontScale:  fontScale,
  );
}

// Backward-compat alias (defaults to dark).
ThemeData buildLinearTheme({Color accent = LinearColors.accent}) =>
    buildLinearDarkTheme(accent: accent);
