import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/error/errors.dart';
import '../../../core/extensions/context_ext.dart';
import '../../location/domain/entities/place.dart';
import '../../weather/domain/entities/weather.dart';
import '../../weather/presentation/providers/weather_provider.dart';
import 'share_card.dart';

/// Previews the share image, then hands it to the system share sheet.
Future<void> showShareCard(
  BuildContext context, {
  required Weather weather,
  required Place place,
  required String name,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ShareSheet(weather: weather, place: place, name: name),
);

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({
    required this.weather,
    required this.place,
    required this.name,
  });

  final Weather weather;
  final Place place;
  final String name;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _card = GlobalKey();
  final _button = GlobalKey();
  var _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    // iPad anchors the share popover to this rect; phones ignore it.
    final button = _button.currentContext!.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero) & button.size;
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    // ShareCard lays out at a fixed logical size, so this is always
    // 1080×1920, the story size social apps expect.
    final image = await boundary.toImage(
      pixelRatio: 1080 / ShareCard.size.width,
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await runQuietly(
      () => SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(png!.buffer.asUint8List(), mimeType: 'image/png'),
          ],
          fileNameOverrides: const ['skycast.png'],
          // Image only: Messenger, Facebook and Instagram hide themselves
          // from the share sheet when text comes along with it.
          sharePositionOrigin: origin,
        ),
      ),
    );
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final air = ref.watch(airQualityProvider(place.lat, place.lon)).value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            // The card is laid out at its own fixed size and only scaled to
            // fit here, so the exported image never depends on the phone.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.62,
              ),
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: RepaintBoundary(
                    key: _card,
                    child: ShareCard(
                      weather: widget.weather,
                      name: widget.name,
                      air: air,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: _button,
                onPressed: _sharing ? null : _share,
                icon: const Icon(Symbols.ios_share_rounded, size: 20),
                label: Text(context.l10n.share),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
