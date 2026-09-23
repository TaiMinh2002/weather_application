import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/prefs.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.onboarded, true);
    if (context.mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.wb_sunny, size: 96, color: context.colors.sunny),
              const SizedBox(height: 24),
              Text(
                l10n.onboardingTitle,
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.onboardingBody,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _finish(context, ref),
                  child: Text(l10n.onboardingStart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
