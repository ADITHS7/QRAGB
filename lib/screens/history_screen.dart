import 'package:flutter/material.dart';

import '../models/app_type.dart';
import '../models/food_gift_history.dart';

/// Authenticated server history. Tapping an entry pops it back to the scanner,
/// which re-opens the result sheet for it.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.appType,
    this.loadRemoteHistory,
    super.key,
  });

  final AppType appType;
  final Future<FoodGiftHistoryResponse> Function()? loadRemoteHistory;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<FoodGiftHistoryResponse>? _remoteFuture;

  @override
  void initState() {
    super.initState();
    if (widget.loadRemoteHistory != null) {
      _remoteFuture = _requestRemoteHistory();
    }
  }

  Future<FoodGiftHistoryResponse> _requestRemoteHistory() {
    final loader = widget.loadRemoteHistory;
    if (loader == null) {
      return Future<FoodGiftHistoryResponse>.value(
        const FoodGiftHistoryResponse(
          entries: <FoodGiftHistoryEntry>[],
          count: 0,
        ),
      );
    }
    return Future<FoodGiftHistoryResponse>.sync(loader);
  }

  void _retryRemoteHistory() {
    if (widget.loadRemoteHistory == null) return;
    setState(() {
      _remoteFuture = _requestRemoteHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loader = widget.loadRemoteHistory;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('History'),
      ),
      body: loader == null
          ? Center(
              child: Text(
                'Server history is not available for ${widget.appType.label}.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [_buildRemoteSection(context)],
            ),
    );
  }

  Widget _buildRemoteSection(BuildContext context) {
    return FutureBuilder<FoodGiftHistoryResponse>(
      future: _remoteFuture,
      builder: (context, snapshot) {
        final count = snapshot.data?.count;
        final children = <Widget>[
          _SectionHeader(
            title: count == null
                ? 'Server history'
                : 'Server history · Count: $count',
          ),
        ];

        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.active) {
          children.add(
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Loading server history...'),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.error.toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _retryRemoteHistory,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        } else {
          final entries =
              snapshot.data?.entries ?? const <FoodGiftHistoryEntry>[];
          if (entries.isEmpty) {
            children.add(
              const _SectionMessage(message: 'No server history found.'),
            );
          } else {
            for (var index = 0; index < entries.length; index++) {
              children.add(_remoteTile(context, entries[index]));
              if (index < entries.length - 1) {
                children.add(const Divider(height: 1, indent: 72));
              }
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  Widget _remoteTile(BuildContext context, FoodGiftHistoryEntry entry) {
    final colors = Theme.of(context).colorScheme;
    final selectable = entry.barcode != null;
    final subtitleParts = <String>[widget.appType.label];
    final recordedAt = entry.recordedAt;
    if (recordedAt != null) subtitleParts.add(_formatDateTime(recordedAt));
    if (!selectable) subtitleParts.add('Not selectable');

    return ListTile(
      enabled: selectable,
      leading: Icon(
        selectable ? Icons.history_rounded : Icons.info_outline_rounded,
        color: selectable ? colors.primary : colors.onSurfaceVariant,
      ),
      title: Text(
        entry.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      onTap: selectable
          ? () {
              final result = entry.toScanResult();
              if (result != null) Navigator.of(context).pop(result);
            }
          : null,
    );
  }

  static String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String _formatDateTime(DateTime time) {
    final local = time.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
    return '$date ${_formatTime(local)}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: colors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
