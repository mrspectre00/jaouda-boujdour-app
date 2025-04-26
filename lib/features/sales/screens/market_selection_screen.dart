import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../widgets/app_layout.dart';
import '../../../features/markets/screens/markets_list_screen.dart';

class MarketSelectionScreen extends ConsumerWidget {
  const MarketSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppLayout(
      title: 'Select a Market',
      body: const MarketsListScreen(
        selectionMode: true,
        routePrefix: '/sales/record',
      ),
    );
  }
}
