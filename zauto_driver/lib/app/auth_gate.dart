import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/app_config.dart';

import '../services/auth_service.dart';
import '../services/backend_service.dart';

import '../controllers/settings_controller.dart';

import '../pages/login_page.dart';

import 'main_screen.dart';

class AuthGate extends StatefulWidget {
  final SettingsController settingsController;

  const AuthGate({super.key, required this.settingsController});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService auth = AuthService();

  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  bool loading = true;

  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();

    refreshAuth();
  }

  Future<void> refreshAuth() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final currentUser = await auth.getCurrentUser();

      if (!mounted) return;

      setState(() {
        user = currentUser;
      });

      if (currentUser != null) {
        await registerPushDevice();
      }
    } catch (error) {
      debugPrint('AUTH CHECK ERROR: $error');

      if (mounted) {
        setState(() {
          user = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> logout() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null && token.isNotEmpty) {
        await backend.unregisterDevice(token);
      }
    } catch (error) {
      debugPrint('DEVICE UNREGISTER ERROR: $error');
    }

    // Sau khi unregister device
    // moi revoke JWT.
    await auth.logout();

    if (!mounted) return;

    setState(() {
      user = null;
    });
  }

  Future<void> registerPushDevice() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await backend.registerDevice(
        token: token,

        platform: Platform.isIOS ? 'ios' : 'android',
      );

      debugPrint('USER DEVICE REGISTERED');
    } catch (error) {
      debugPrint('USER DEVICE REGISTER ERROR: $error');
    }
  }

  Future<void> accountDeleted() async {
    // Account backend da bi xoa,
    // khong goi /logout nua.
    await auth.clearLocalSession();

    if (!mounted) {
      return;
    }

    setState(() {
      user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return LoginPage(onAuthenticated: refreshAuth);
    }

    // ========================================
    // DA LOGIN
    // LUON VAO MAIN SCREEN
    // DU DA LINK ZALO HAY CHUA
    // ========================================

    return MainScreen(
      user: user!,

      onLogout: logout,

      onAuthChanged: refreshAuth,

      onAccountDeleted: accountDeleted,

      settingsController: widget.settingsController,
    );
  }
}
