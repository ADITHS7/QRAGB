import 'package:flutter/material.dart';

import '../models/app_type.dart';
import '../models/auth_user.dart';
import '../viewmodels/login_view_model.dart';

/// Login form shown only after an app type has been selected.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.appType,
    required this.onLoginSuccess,
    required this.onChangeAppType,
    super.key,
  });

  final AppType appType;
  final ValueChanged<AuthUser> onLoginSuccess;
  final VoidCallback onChangeAppType;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final LoginViewModel _viewModel;
  bool _successReported = false;

  @override
  void initState() {
    super.initState();
    _viewModel = LoginViewModel(appType: widget.appType);
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {});

    final user = _viewModel.user;
    if (!_successReported &&
        _viewModel.state == LoginState.success &&
        user != null) {
      _successReported = true;
      widget.onLoginSuccess(user);
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    _usernameFocus.unfocus();
    _passwordFocus.unfocus();
    _viewModel.login(_usernameController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loading = _viewModel.state == LoginState.loading;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.fingerprint,
                      color: colors.onPrimary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'DigiVerify',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in for ${widget.appType.label}',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SelectedTypeChip(
                    type: widget.appType,
                    onChange: widget.onChangeAppType,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Username'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          focusNode: _usernameFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          onChanged: (_) => _viewModel.resetError(),
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurface,
                          ),
                          decoration: _inputDecoration(
                            context,
                            hint: 'Enter username',
                            icon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Password'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _viewModel.obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          onChanged: (_) => _viewModel.resetError(),
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurface,
                          ),
                          decoration: _inputDecoration(
                            context,
                            hint: 'Enter password',
                            icon: Icons.lock_rounded,
                            suffix: IconButton(
                              icon: Icon(
                                _viewModel.obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                              onPressed: _viewModel.toggleObscure,
                            ),
                          ),
                        ),
                        if (_viewModel.state == LoginState.error &&
                            _viewModel.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 14,
                                  color: colors.error,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _viewModel.errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              disabledBackgroundColor:
                                  colors.surfaceContainerHighest,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: loading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: loading ? null : widget.onChangeAppType,
                    child: const Text('Change app type'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final colors = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: colors.onSurfaceVariant),
      suffixIcon: suffix,
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    );
  }
}

class _SelectedTypeChip extends StatelessWidget {
  const _SelectedTypeChip({required this.type, required this.onChange});

  final AppType type;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_rounded, color: colors.primary, size: 18),
        const SizedBox(width: 6),
        Text(
          '${type.label} app selected',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(onPressed: onChange, child: const Text('Change')),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
