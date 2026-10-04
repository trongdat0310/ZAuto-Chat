import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../services/theme_service.dart';

import 'auth_gate.dart';

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
            return ValueListenableBuilder<double>(
              valueListenable:
                  settingsController.notificationFontSize,

              child:
                  child ??
                  const SizedBox.shrink(),

              builder: (context, fontSize, appChild) {
                final mediaQuery =
                    MediaQuery.of(context);

                final systemScale =
                    mediaQuery.textScaler.scale(14) /
                    14;

                final appScale =
                    (fontSize / 15)
                        .clamp(0.67, 2.0);

                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(
                      systemScale *
                          appScale,
                    ),
                  ),
                  child: Listener(
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
                        appChild ??
                        const SizedBox.shrink(),
                  ),
                );
              },
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
  }
}
