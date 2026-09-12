import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_type.dart';
import '../models/auth_user.dart';
import '../screens/app_type_screen.dart';
import '../screens/login_screen.dart';
import '../screens/scanner_screen.dart';
import '../services/auth_storage.dart';

/// Restores the saved session and ensures the camera is created only after
/// authentication succeeds.
class AuthGate extends StatefulWidget {
  const AuthGate({this.onAppTypeChanged, super.key});

  final ValueChanged<AppType?>? onAppTypeChanged;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthStorage _storage = AuthStorage();

  AppType? _selectedType;
  AuthUser? _user;
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final selectedType = await _storage.readSelectedType();
      final session = await _storage.readSession();

      if (session != null &&
          (selectedType == null || selectedType == session.appType)) {
        _selectedType = session.appType;
        _user = session;
        if (selectedType == null) {
          await _storage.saveSelectedType(session.appType);
        }
      } else {
        if (session != null) await _storage.clearSession();
        _selectedType = selectedType;
      }
    } catch (error) {
      _loadError = error;
    }

    if (!mounted) return;
    widget.onAppTypeChanged?.call(_user?.appType ?? _selectedType);
    setState(() => _loading = false);
  }

  Future<void> _onTypeSelected(AppType type) async {
    await _storage.clearSession();
    await _storage.saveSelectedType(type);
    if (!mounted) return;
    widget.onAppTypeChanged?.call(type);
    setState(() {
      _selectedType = type;
      _user = null;
      _loadError = null;
    });
  }

  void _onLoginSuccess(AuthUser user) {
    if (!mounted) return;
    widget.onAppTypeChanged?.call(user.appType);
    setState(() {
      _selectedType = user.appType;
      _user = user;
      _loadError = null;
    });
  }

  Future<void> _changeAppType() async {
    await _storage.clearAll();
    if (!mounted) return;
    widget.onAppTypeChanged?.call(null);
    setState(() {
      _selectedType = null;
      _user = null;
      _loadError = null;
    });
  }

  Future<void> _logout() async {
    await _storage.clearSession();
    if (!mounted) return;
    setState(() {
      _user = null;
      _loadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _GateLoading();
    if (_loadError != null) {
      return _GateError(onRetry: _reload, error: _loadError!);
    }
    if (_user != null) {
      return ScannerScreen(
        appType: _user!.appType,
        token: _user!.token,
        onLogout: _logout,
      );
    }
    if (_selectedType == null) {
      return AppTypeScreen(onSelected: _onTypeSelected);
    }
    return LoginScreen(
      appType: _selectedType!,
      onLoginSuccess: _onLoginSuccess,
      onChangeAppType: _changeAppType,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _restore();
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(child: CircularProgressIndicator(color: colors.primary)),
    );
  }
}

class _GateError extends StatelessWidget {
  const _GateError({required this.onRetry, required this.error});

  final VoidCallback onRetry;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Could not restore the saved session.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
