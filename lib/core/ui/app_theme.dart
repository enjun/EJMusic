import 'package:flutter/material.dart';

/// 全局设计系统：颜色、间距、圆角、阴影与 Material 3 主题。
///
/// 设计取向——「简洁而大气」：
///   * 收敛的调色板：单一主色（靛蓝）+ 中性灰阶 + 少量语义色，
///     页面底色比卡片更暗/更亮一档，让卡片自然浮起而不是靠描边。
///   * 大比例留白：统一 4pt 基准间距，页面横向 24pt 留白。
///   * 轻阴影 + 大圆角：不用重描边，层次靠 elevation 与色阶表达。
class AppColors {
  const AppColors._();

  /// 主色：靛蓝。稳重、专业，适合乐谱工具。
  static const primary = Color(0xFF4F46C8);
  static const primaryDark = Color(0xFFB4ADFF);

  /// 强调色：琥珀金，用于主操作之外的视觉焦点。
  static const accent = Color(0xFFC97A16);

  // ---- 浅色模式 ----
  static const lightSurface = Color(0xFFF7F7FB);
  static const lightSurfaceCard = Color(0xFFFFFFFF);
  static const lightSurfaceSunken = Color(0xFFEFEFF6);
  static const lightSurfaceHigh = Color(0xFFE8E8F1);
  static const lightOnSurface = Color(0xFF191A21);
  static const lightOnSurfaceVariant = Color(0xFF5B5D6B);
  static const lightOutline = Color(0xFFD5D6E0);
  static const lightOutlineVariant = Color(0xFFE7E8EF);

  // ---- 深色模式 ----
  static const darkSurface = Color(0xFF121319);
  static const darkSurfaceCard = Color(0xFF1A1C23);
  static const darkSurfaceSunken = Color(0xFF0D0E13);
  static const darkSurfaceHigh = Color(0xFF24262F);
  static const darkOnSurface = Color(0xFFE8E9F0);
  static const darkOnSurfaceVariant = Color(0xFFA9ABB9);
  static const darkOutline = Color(0xFF3A3C47);
  static const darkOutlineVariant = Color(0xFF2A2C35);

  // ---- 语义色 ----
  static const success = Color(0xFF2E9E5B);
  static const warning = Color(0xFFD08B14);
  static const info = Color(0xFF2FA8C4);
  static const danger = Color(0xFFD0453B);
}

/// 谱面纸色：浅色模式用微暖白，深色模式用深灰纸，避免纯白刺眼。
class SheetThemeColors {
  const SheetThemeColors({
    required this.background,
    required this.foreground,
    required this.paper,
    required this.shadow,
    required this.outline,
  });

  final Color background;
  final Color foreground;
  final Color paper;
  final Color shadow;
  final Color outline;

  /// 从应用主题推导谱面配色，供 WebView 宿主页（OSMD 渲染层）使用。
  factory SheetThemeColors.of(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return SheetThemeColors(
      background: theme.colorScheme.surface,
      foreground: theme.colorScheme.onSurface,
      paper: dark ? const Color(0xFF1C1E26) : const Color(0xFFFFFFFF),
      shadow: dark ? const Color(0x66000000) : const Color(0x1A14161F),
      outline: dark ? const Color(0x33FFFFFF) : const Color(0x1414161F),
    );
  }
}

/// 4pt 基准间距。
class AppSpacing {
  const AppSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// 页面内容横向留白（窗口窄时自动收窄）。
  static double pageMargin(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 720 ? md : lg;
}

class AppRadius {
  const AppRadius._();

  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const pill = 999.0;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// 轻阴影：层次主要由表面色阶承担，阴影只做轻微托底。
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> soft(Brightness brightness) =>
      brightness == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0F14161F),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0A14161F),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ];

  static List<BoxShadow> lifted(Brightness brightness) =>
      brightness == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x1A14161F),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x0D14161F),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ];
}

/// 主题构建：浅色 / 深色。
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(_lightScheme, Brightness.light);

  static ThemeData dark() => _build(_darkScheme, Brightness.dark);

  // ---------------------------------------------------------------- 调色板

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE4E1FF),
    onPrimaryContainer: Color(0xFF1B1454),
    primaryFixed: Color(0xFFE4E1FF),
    primaryFixedDim: Color(0xFFC6C0FF),
    onPrimaryFixed: Color(0xFF1B1454),
    onPrimaryFixedVariant: Color(0xFF3A31A8),
    secondary: Color(0xFF5C5E77),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE5E6F5),
    onSecondaryContainer: Color(0xFF1C1D2E),
    secondaryFixed: Color(0xFFE5E6F5),
    secondaryFixedDim: Color(0xFFCBCDE4),
    onSecondaryFixed: Color(0xFF1C1D2E),
    onSecondaryFixedVariant: Color(0xFF44465C),
    tertiary: AppColors.accent,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE8C7),
    onTertiaryContainer: Color(0xFF3D2600),
    tertiaryFixed: Color(0xFFFFE8C7),
    tertiaryFixedDim: Color(0xFFF5CE94),
    onTertiaryFixed: Color(0xFF3D2600),
    onTertiaryFixedVariant: Color(0xFF6A4A0C),
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: Color(0xFFFCE3E1),
    onErrorContainer: Color(0xFF4A0F0B),
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    surfaceDim: Color(0xFFE3E3EC),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFCFCFE),
    surfaceContainer: AppColors.lightSurfaceCard,
    surfaceContainerHigh: AppColors.lightSurfaceHigh,
    surfaceContainerHighest: AppColors.lightSurfaceSunken,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2C2D36),
    onInverseSurface: Color(0xFFF2F2F7),
    inversePrimary: AppColors.primaryDark,
    surfaceTint: AppColors.primary,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    onPrimary: Color(0xFF231A6B),
    primaryContainer: Color(0xFF352C93),
    onPrimaryContainer: Color(0xFFE4E1FF),
    primaryFixed: Color(0xFFE4E1FF),
    primaryFixedDim: Color(0xFFC6C0FF),
    onPrimaryFixed: Color(0xFF1B1454),
    onPrimaryFixedVariant: Color(0xFF3A31A8),
    secondary: Color(0xFFB9BBCC),
    onSecondary: Color(0xFF2A2B3C),
    secondaryContainer: Color(0xFF3E4054),
    onSecondaryContainer: Color(0xFFE5E6F5),
    secondaryFixed: Color(0xFFE5E6F5),
    secondaryFixedDim: Color(0xFFCBCDE4),
    onSecondaryFixed: Color(0xFF1C1D2E),
    onSecondaryFixedVariant: Color(0xFF44465C),
    tertiary: Color(0xFFF0B65E),
    onTertiary: Color(0xFF432B00),
    tertiaryContainer: Color(0xFF5F3F04),
    onTertiaryContainer: Color(0xFFFFE8C7),
    tertiaryFixed: Color(0xFFFFE8C7),
    tertiaryFixedDim: Color(0xFFF5CE94),
    onTertiaryFixed: Color(0xFF3D2600),
    onTertiaryFixedVariant: Color(0xFF6A4A0C),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    surfaceDim: Color(0xFF0D0E13),
    surfaceBright: Color(0xFF35373F),
    surfaceContainerLowest: AppColors.darkSurfaceSunken,
    surfaceContainerLow: Color(0xFF16171D),
    surfaceContainer: AppColors.darkSurfaceCard,
    surfaceContainerHigh: Color(0xFF21232B),
    surfaceContainerHighest: AppColors.darkSurfaceHigh,
    onSurfaceVariant: AppColors.darkOnSurfaceVariant,
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE8E9F0),
    onInverseSurface: Color(0xFF2C2D36),
    inversePrimary: AppColors.primary,
    surfaceTint: AppColors.primaryDark,
  );

  // ------------------------------------------------------------------ 构建

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: _textTheme(base.primaryTextTheme, scheme),
      scaffoldBackgroundColor: scheme.surface,
      // 涟漪与选中态统一到主色，避免默认紫色的残留
      splashColor: scheme.primary.withValues(alpha: 0.10),
      highlightColor: scheme.primary.withValues(alpha: 0.05),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.md,
        toolbarHeight: 64,
        titleTextStyle: text.titleLarge,
        actionsPadding: const EdgeInsets.only(right: AppSpacing.xs),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        actionsIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x1A14161F),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        minVerticalPadding: AppSpacing.sm,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(scheme, true),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(scheme, true),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _buttonStyle(scheme, false),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 2,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        border: _inputBorder(scheme.outlineVariant),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 1.6),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
        disabledBorder: _inputBorder(scheme.outlineVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: scheme.outline, width: 1.6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHigh,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHigh,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? scheme.surfaceContainerHighest
            : const Color(0xFF2A2B36),
        contentTextStyle: text.bodyMedium?.copyWith(
          color: const Color(0xFFF4F4F8),
        ),
        actionTextColor: AppColors.primaryDark,
        elevation: 3,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? scheme.surfaceContainerHighest
              : const Color(0xFF2A2B36),
          borderRadius: AppRadius.smAll,
        ),
        textStyle: text.labelMedium?.copyWith(color: const Color(0xFFF4F4F8)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        textStyle: text.bodyMedium,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          scheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(AppRadius.pill),
        crossAxisMargin: 2,
      ),
      dividerColor: scheme.outlineVariant,
    );
  }

  static ButtonStyle _buttonStyle(ColorScheme scheme, bool filled) =>
      ButtonStyle(
        backgroundColor: filled
            ? WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? scheme.surfaceContainerHigh
                    : scheme.primary,
              )
            : const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: filled
            ? WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : scheme.onPrimary,
              )
            : WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                    : scheme.primary,
              ),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.08),
        ),
        side: filled
            ? const WidgetStatePropertyAll(BorderSide.none)
            : WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Color(0x1A14161F)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );

  /// 中文优先字体栈 + 收敛的字号/字重层级。
  static const _fontFamilyFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'Hiragino Sans GB',
    'Segoe UI',
    'Roboto',
  ];

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle? s(
      TextStyle? style, {
      double? size,
      FontWeight? weight,
      double? height,
      double? spacing,
      Color? color,
    }) => style?.copyWith(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color,
      fontFamilyFallback: _fontFamilyFallback,
    );

    return base.copyWith(
      displaySmall: s(
        base.displaySmall,
        size: 36,
        weight: FontWeight.w700,
        height: 1.2,
        spacing: -0.5,
      ),
      headlineMedium: s(
        base.headlineMedium,
        size: 28,
        weight: FontWeight.w700,
        height: 1.25,
        spacing: -0.3,
      ),
      headlineSmall: s(
        base.headlineSmall,
        size: 23,
        weight: FontWeight.w700,
        height: 1.3,
        spacing: -0.2,
      ),
      titleLarge: s(
        base.titleLarge,
        size: 19,
        weight: FontWeight.w600,
        height: 1.35,
      ),
      titleMedium: s(
        base.titleMedium,
        size: 16,
        weight: FontWeight.w600,
        height: 1.4,
      ),
      titleSmall: s(
        base.titleSmall,
        size: 14,
        weight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: s(
        base.bodyLarge,
        size: 15,
        weight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: s(
        base.bodyMedium,
        size: 14,
        weight: FontWeight.w400,
        height: 1.6,
        color: scheme.onSurfaceVariant,
      ),
      bodySmall: s(
        base.bodySmall,
        size: 12.5,
        weight: FontWeight.w400,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: s(
        base.labelLarge,
        size: 14,
        weight: FontWeight.w600,
        spacing: 0.1,
      ),
      labelMedium: s(
        base.labelMedium,
        size: 12.5,
        weight: FontWeight.w600,
        spacing: 0.2,
      ),
      labelSmall: s(
        base.labelSmall,
        size: 11.5,
        weight: FontWeight.w500,
        spacing: 0.3,
      ),
    );
  }
}
