import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../services/theme_service.dart';

import 'auth_gate.dart';

class ZautoDriverApp extends StatelessWidget {
  final SettingsController settingsController;

  const ZautoDriverApp({super.key, required this.settingsController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,

      builder: (context, _) {
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
            return Listener(
              behavior:
                  HitTestBehavior.translucent,

              onPointerDown: (event) {
                final focus =
                    FocusManager.instance.primaryFocus;

                if (
                  focus == null ||
                  !focus.hasFocus
                ) {
                  return;
                }


                final focusContext =
                    focus.context;

                final renderObject =
                    focusContext
                        ?.findRenderObject();


                if (
                  renderObject is RenderBox &&
                  renderObject.hasSize
                ) {
                  final localPosition =
                      renderObject.globalToLocal(
                    event.position,
                  );


                  final insideFocusedField =
                      localPosition.dx >= 0 &&
                      localPosition.dy >= 0 &&
                      localPosition.dx <=
                          renderObject.size.width &&
                      localPosition.dy <=
                          renderObject.size.height;


                  if (insideFocusedField) {
                    return;
                  }
                }


                focus.unfocus();
              },

              child:
                  child ??
                  const SizedBox.shrink(),
            );
          },

          // ========================================
          // LIGHT THEME
          // ========================================
          theme: ThemeData(
            useMaterial3: true,

            brightness: Brightness.light,

            colorSchemeSeed: Colors.blue,
          ),

          // ========================================
          // DARK THEME
          // ========================================
          darkTheme: ThemeData(
            useMaterial3: true,

            brightness: Brightness.dark,

            colorSchemeSeed: Colors.blue,
          ),

          themeMode: themeMode,

              home: AuthGate(
                settingsController:
                    settingsController,
              ),
            );
          },
        );
      },
    );
  }
}
