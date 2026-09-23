import 'package:flutter/material.dart';

import '../error/errors.dart';
import '../extensions/context_ext.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, message) = switch (error) {
      NetworkFailure() => (Icons.wifi_off, l10n.errorNetwork),
      ServerFailure() => (Icons.cloud_off, l10n.errorServer),
      CacheFailure() => (Icons.inventory_2_outlined, l10n.errorCache),
      LocationFailure() => (Icons.location_off, l10n.errorLocation),
      _ => (Icons.error_outline, l10n.errorUnknown),
    };
    return _MessageView(
      icon: icon,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message, this.icon = Icons.inbox_outlined});

  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      _MessageView(icon: icon, message: message ?? context.l10n.emptyDefault);
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: context.colors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
