import 'package:flutter/material.dart';

import '../models/app_type.dart';
import '../theme.dart';

/// First-run screen. The user must choose exactly one operating mode before
/// the login form becomes available.
class AppTypeScreen extends StatefulWidget {
  const AppTypeScreen({required this.onSelected, super.key});

  final Future<void> Function(AppType type) onSelected;

  @override
  State<AppTypeScreen> createState() => _AppTypeScreenState();
}

class _AppTypeScreenState extends State<AppTypeScreen> {
  bool _saving = false;

  Future<void> _select(AppType type) async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.onSelected(type);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    color: colors.primary,
                    size: 58,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Choose app type',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the service you are signing in to.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _TypeCard(
                    type: AppType.food,
                    icon: Icons.restaurant_rounded,
                    description: 'Scan and submit food entries.',
                    enabled: !_saving,
                    onTap: _select,
                  ),
                  const SizedBox(height: 12),
                  _TypeCard(
                    type: AppType.gift,
                    icon: Icons.card_giftcard_rounded,
                    description: 'Scan and manage gift entries.',
                    enabled: !_saving,
                    onTap: _select,
                  ),
                  const SizedBox(height: 12),
                  _TypeCard(
                    type: AppType.entry,
                    icon: Icons.login_rounded,
                    description: 'Scan and manage entry records.',
                    enabled: !_saving,
                    onTap: _select,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.icon,
    required this.description,
    required this.enabled,
    required this.onTap,
  });

  final AppType type;
  final IconData icon;
  final String description;
  final bool enabled;
  final ValueChanged<AppType> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppThemePalette.forType(type);
    return Material(
      color: palette.surfaceHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? () => onTap(type) : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: palette.accent, size: 27),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
