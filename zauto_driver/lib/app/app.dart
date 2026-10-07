import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../services/theme_service.dart';
import '../theme/app_typography.dart';

import 'auth_gate.dart';

ThemeData _buildTheme(
  Brightness brightness,
) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: Colors.blue,
    fontFamily: AppTypography.fontFamily,
  );


  return base.copyWith(
    textTheme:
        AppTypography.textTheme(
      base.textTheme,
    ),

    primaryTextTheme:
        AppTypography.textTheme(
      base.primaryTextTheme,
    ),

    appBarTheme:
        base.appBarTheme.copyWith(
      titleTextStyle:
          AppTypography.pageTitle.copyWith(
        color:
            base.colorScheme.onSurface,
      ),
    ),

    tabBarTheme:
        base.tabBarTheme.copyWith(
      labelStyle:
          AppTypography.tab,
      unselectedLabelStyle:
          AppTypography.tab.copyWith(
        fontWeight:
            FontWeight.w500,
      ),
    ),

    textButtonTheme:
        TextButtonThemeData(
      style:
          TextButton.styleFrom(
        textStyle:
            AppTypography.button,
      ),
    ),

    filledButtonTheme:
        FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
        textStyle:
            AppTypography.button,
      ),
    ),

    outlinedButtonTheme:
        OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
        textStyle:
            AppTypography.button,
      ),
    ),

    navigationBarTheme:
        base.navigationBarTheme.copyWith(
      labelTextStyle:
          WidgetStatePropertyAll(
        AppTypography.caption.copyWith(
          fontWeight:
              FontWeight.w600,
        ),
      ),
    ),
  );
}


class ZautoDriverApp extends StatelessWidget {
  final SettingsController settingsController;

  const ZautoDriverApp({super.key, required this.settingsController});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,

      builder: (context, themeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: 'Driver Assistant',

          // ========================================
          // GLOBAL KEYBOARD DISMISS
          //
          // Cham ra ngoai o dang nhap:
          // - bo focus
          // - ha ban phim
          //
          // Listener chi quan sat pointer nen khong
          // chan tap/scroll cua widget ben duoi.
          // ========================================

          builder: (context, child) {
            return GestureDetector(
              behavior:
                  HitTestBehavior.translucent,

              // ========================================
              // GLOBAL KEYBOARD DISMISS
              //
              // Dung gesture arena thay vi raw pointer:
              // - tap vung trong -> parent win -> unfocus
              // - tap button/control -> child win -> KHONG unfocus
              //
              // Nho vay nut Send trong Chat giu nguyen keyboard,
              // trong khi tap ra ngoai van ha keyboard nhu cu.
              // ========================================

              onTap: () {
                final focus =
                    FocusManager.instance.primaryFocus;

                if (
                  focus != null &&
                  focus.hasFocus
                ) {
                  focus.unfocus();
                }
              },

              child:
                  child ??
                  const SizedBox.shrink(),
            );
          },

          // ========================================
          // LIGHT THEME
          // ========================================
          theme: _buildTheme(
            Brightness.light,
          ),

          // ========================================
          // DARK THEME
          // ========================================
          darkTheme: _buildTheme(
            Brightness.dark,
          ),

          themeMode: themeMode,

          home: AuthGate(
            settingsController:
                settingsController,
          ),
        );
      },
    );
  }
}
