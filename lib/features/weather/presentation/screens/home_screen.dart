import 'package:flutter/material.dart';

import '../../../../core/extensions/context_ext.dart';
import '../../../../core/widgets/state_views.dart';

// ponytail: placeholder until the weather feature (plan.md day 3–6) lands.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.appTitle)),
    body: const EmptyView(icon: Icons.cloud_outlined),
  );
}
