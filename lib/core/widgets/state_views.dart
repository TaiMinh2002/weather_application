import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../error/errors.dart';
import '../extensions/context_ext.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.extraAction,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Shown after the built-in buttons, e.g. "Choose a city" on Home.
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, message) = switch (error) {
      NetworkFailure() => (Symbols.wifi_off_rounded, l10n.errorNetwork),
      ServerFailure() => (Symbols.cloud_off_rounded, l10n.errorServer),
      CacheFailure() => (Symbols.inventory_2_rounded, l10n.errorCache),
      LocationFailure(:final reason) => (
        reason == LocationError.serviceDisabled
            ? Symbols.gps_off_rounded
            : Symbols.location_off_rounded,
        switch (reason) {
          LocationError.serviceDisabled => l10n.errorLocationDisabled,
          LocationError.denied => l10n.errorLocationDenied,
          LocationError.deniedForever => l10n.errorLocationDeniedForever,
          LocationError.unavailable => l10n.errorLocation,
        },
      ),
      _ => (Symbols.error_rounded, l10n.errorUnknown),
    };
    // Retrying can't fix these; the user must change a system setting first.
    final openSettings = switch (error) {
      LocationFailure(reason: LocationError.serviceDisabled) =>
        Geolocator.openLocationSettings,
      LocationFailure(reason: LocationError.deniedForever) =>
        Geolocator.openAppSettings,
      _ => null,
    };
    return _MessageView(
      icon: icon,
      message: message,
      action: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          if (onRetry != null)
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          if (openSettings != null)
            FilledButton.tonal(
              onPressed: openSettings,
              child: Text(l10n.openSettings),
            ),
          ?extraAction,
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.message,
    this.icon = Symbols.inbox_rounded,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  final String? message;
  final IconData icon;

  /// Secondary line under [message], in textMuted.
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _MessageView(
    icon: icon,
    message: message ?? context.l10n.emptyDefault,
    hint: hint,
    action: actionLabel == null
        ? null
        : FilledButton(onPressed: onAction, child: Text(actionLabel!)),
  );
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, weight: 300, color: context.colors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge,
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
