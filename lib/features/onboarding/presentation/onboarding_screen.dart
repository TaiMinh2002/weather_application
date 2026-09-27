import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_ext.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/prefs.dart';
import '../../location/data/repositories/location_repository_impl.dart';

/// Shown once. Explains the location permission before the system asks.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  var _asking = false;

  Future<void> _allowLocation() async {
    if (_asking) return;
    setState(() => _asking = true);
    // Opens the system permission dialog while the reason is on screen. The
    // result is ignored on purpose: if it's denied or GPS is off, Home's GPS
    // page explains why and offers the fix.
    await ref.read(locationRepositoryProvider).getCurrentPlace();
    await _finish();
  }

  Future<void> _finish({bool chooseCity = false}) async {
    await ref.read(sharedPreferencesProvider).setBool(PrefKeys.onboarded, true);
    if (!mounted) return;
    context.go(Routes.home);
    if (chooseCity) context.push(Routes.cities);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textTheme;
    final scheme = context.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Takes whatever the text and buttons leave (about 55% on a
            // phone, as in the design) so short screens don't overflow.
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Center(
                  child: _Illustration(
                    size: math.min(240, box.maxHeight * 0.8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                spacing: 12,
                children: [
                  Text(
                    l10n.onboardingTitle,
                    textAlign: TextAlign.center,
                    style: text.titleLarge,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      l10n.onboardingBody,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _allowLocation,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 10,
                      children: [
                        if (_asking)
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          ),
                        Text(l10n.allowLocation),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _asking ? null : () => _finish(chooseCity: true),
                    child: Text(l10n.chooseCityManually),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Location pin over a sun and a cloud, from simple shapes (no image asset).
class _Illustration extends StatelessWidget {
  const _Illustration({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final colors = context.colors;
    final pin = size * 0.46;
    final cloud = size * 0.28;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: size),
          ),
          // A square with one sharp corner, turned so that corner points down.
          Transform.rotate(
            angle: -math.pi / 4,
            child: Container(
              width: pin,
              height: pin,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(pin / 2),
                  topRight: Radius.circular(pin / 2),
                  bottomRight: Radius.circular(pin / 2),
                ),
              ),
              child: Container(
                width: pin * 0.33,
                height: pin * 0.33,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.06,
            right: size * 0.02,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: BoxDecoration(
                color: colors.sunny,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.1,
            left: -cloud * 0.15,
            child: Container(
              width: cloud,
              height: cloud * 0.6,
              decoration: BoxDecoration(
                color: colors.rainy,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
