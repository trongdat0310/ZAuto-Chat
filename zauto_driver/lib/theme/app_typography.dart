import 'package:flutter/material.dart';


class AppTypography {
  AppTypography._();


  static const String fontFamily =
      'Roboto';


  static const TextStyle pageTitle =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );


  static const TextStyle sheetTitle =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );


  static const TextStyle sectionTitle =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );


  static const TextStyle itemTitle =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );


  static const TextStyle body =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.35,
      );


  static const TextStyle bodyStrong =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );


  static const TextStyle caption =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.25,
      );


  static const TextStyle button =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );


  static const TextStyle tab =
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      );


  static TextTheme textTheme(
    TextTheme base,
  ) {
    return base.copyWith(
      displayLarge:
          base.displayLarge?.copyWith(
        fontFamily: fontFamily,
      ),
      displayMedium:
          base.displayMedium?.copyWith(
        fontFamily: fontFamily,
      ),
      displaySmall:
          base.displaySmall?.copyWith(
        fontFamily: fontFamily,
      ),
      headlineLarge:
          base.headlineLarge?.merge(pageTitle),
      headlineMedium:
          base.headlineMedium?.merge(sheetTitle),
      headlineSmall:
          base.headlineSmall?.merge(itemTitle),
      titleLarge:
          base.titleLarge?.merge(pageTitle),
      titleMedium:
          base.titleMedium?.merge(itemTitle),
      titleSmall:
          base.titleSmall?.merge(sectionTitle),
      bodyLarge:
          base.bodyLarge?.merge(body),
      bodyMedium:
          base.bodyMedium?.merge(body),
      bodySmall:
          base.bodySmall?.merge(caption),
      labelLarge:
          base.labelLarge?.merge(button),
      labelMedium:
          base.labelMedium?.merge(tab),
      labelSmall:
          base.labelSmall?.merge(caption),
    );
  }
}
